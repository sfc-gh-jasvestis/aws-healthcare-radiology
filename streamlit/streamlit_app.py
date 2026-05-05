import streamlit as st
import pandas as pd
import json
import plotly.express as px
import _snowflake
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="Radiology Analytics", layout="wide", page_icon="🩻")

page = st.sidebar.radio("Navigation", ["TAT Dashboard", "Critical Findings", "Productivity", "AI Summary", "Ask Radiology"], label_visibility="collapsed")
st.sidebar.divider()
st.sidebar.markdown("### Radiology Analytics")
st.sidebar.caption("Multi-page app — TAT monitoring, critical findings queue, radiologist productivity")
st.sidebar.divider()
modality_filter = st.sidebar.multiselect("Modality", ["CT", "MRI", "XR", "US", "NM", "PET"])
mod_clause = "','".join(modality_filter) if modality_filter else ""
mod_sql = f"WHERE MODALITY IN ('{mod_clause}')" if modality_filter else ""

if page == "TAT Dashboard":
    st.title("Turnaround Time Dashboard")
    st.caption("SLA targets: CT 120min, MRI 180min, XR 60min, US 90min")
    tat = session.sql(f"""
        SELECT MODALITY, ROUND(AVG(AVG_TAT_MINUTES), 1) AS AVG_TAT,
               SUM(STUDIES_COMPLETED) AS TOTAL_STUDIES,
               SUM(TAT_SLA_BREACH_COUNT) AS BREACHES,
               ROUND(SUM(TAT_SLA_BREACH_COUNT) * 100.0 / NULLIF(SUM(STUDIES_COMPLETED), 0), 1) AS BREACH_PCT
        FROM HEALTHCARE_RADIOLOGY.CURATED.TAT_METRICS
        {mod_sql}
        GROUP BY MODALITY ORDER BY AVG_TAT DESC
    """).to_pandas()
    if not tat.empty:
        for col in ["AVG_TAT", "TOTAL_STUDIES", "BREACHES", "BREACH_PCT"]:
            tat[col] = pd.to_numeric(tat[col], errors="coerce")
        cols = st.columns(len(tat))
        for i, (_, row) in enumerate(tat.iterrows()):
            with cols[i]:
                delta_color = "inverse" if row["AVG_TAT"] > 120 else "normal"
                st.metric(row["MODALITY"], f"{row['AVG_TAT']:.0f} min", delta=f"{row['BREACH_PCT']:.1f}% breach")
        fig = px.bar(tat, x="MODALITY", y="AVG_TAT", color="BREACH_PCT", color_continuous_scale="OrRd",
                     title="Average TAT by Modality (minutes)")
        sla_targets = {"CT": 120, "MRI": 180, "XR": 60, "US": 90, "NM": 120, "PET": 180}
        fig.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

    trend = session.sql(f"""
        SELECT METRIC_DATE, MODALITY, AVG_TAT_MINUTES
        FROM HEALTHCARE_RADIOLOGY.CURATED.TAT_METRICS
        {mod_sql}
        ORDER BY METRIC_DATE
    """).to_pandas()
    if not trend.empty:
        trend["AVG_TAT_MINUTES"] = pd.to_numeric(trend["AVG_TAT_MINUTES"], errors="coerce")
        fig2 = px.line(trend, x="METRIC_DATE", y="AVG_TAT_MINUTES", color="MODALITY", title="TAT Trend Over Time")
        fig2.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig2, use_container_width=True)

elif page == "Critical Findings":
    st.title("Critical Findings Queue")
    st.caption("Unacknowledged critical findings requiring immediate attention")
    crit = session.sql("""
        SELECT FINDING_TYPE, SEVERITY, COUNT(*) AS CNT,
               COUNT(CASE WHEN NOT ACKNOWLEDGED THEN 1 END) AS UNACK
        FROM HEALTHCARE_RADIOLOGY.RAW.CRITICAL_FINDINGS
        GROUP BY FINDING_TYPE, SEVERITY ORDER BY UNACK DESC
    """).to_pandas()
    if not crit.empty:
        crit["CNT"] = pd.to_numeric(crit["CNT"], errors="coerce")
        crit["UNACK"] = pd.to_numeric(crit["UNACK"], errors="coerce")
        total_unack = crit["UNACK"].sum()
        st.metric("Unacknowledged Critical Findings", f"{total_unack:,.0f}")
        fig = px.bar(crit, x="FINDING_TYPE", y="UNACK", color="SEVERITY",
                     color_discrete_map={"CRITICAL": "#FF4B4B", "HIGH": "#FF8C00"},
                     title="Unacknowledged by Finding Type")
        fig.update_layout(height=350, margin=dict(t=40, b=10))
        st.plotly_chart(fig, use_container_width=True)

    queue = session.sql("""
        SELECT cf.FINDING_ID, s.MODALITY, s.BODY_PART, cf.FINDING_TYPE, cf.SEVERITY,
               s.STUDY_DATE, cf.FINDING_ID AS ID
        FROM HEALTHCARE_RADIOLOGY.RAW.CRITICAL_FINDINGS cf
        JOIN HEALTHCARE_RADIOLOGY.RAW.STUDIES s ON cf.STUDY_ID = s.STUDY_ID
        WHERE NOT cf.ACKNOWLEDGED
        ORDER BY cf.SEVERITY DESC, s.STUDY_DATE DESC
        LIMIT 25
    """).to_pandas()
    if not queue.empty:
        st.dataframe(queue, use_container_width=True)

elif page == "Productivity":
    st.title("Radiologist Productivity")
    prod = session.sql("""
        SELECT RADIOLOGIST_NAME, SUBSPECIALTY, DAILY_READS, AVG_TAT_MINUTES
        FROM HEALTHCARE_RADIOLOGY.CURATED.RADIOLOGIST_PRODUCTIVITY
        WHERE METRIC_DATE = (SELECT MAX(METRIC_DATE) FROM HEALTHCARE_RADIOLOGY.CURATED.RADIOLOGIST_PRODUCTIVITY)
        ORDER BY DAILY_READS DESC
        LIMIT 20
    """).to_pandas()
    if not prod.empty:
        for col in ["DAILY_READS", "AVG_TAT_MINUTES"]:
            prod[col] = pd.to_numeric(prod[col], errors="coerce")
        fig = px.bar(prod, x="RADIOLOGIST_NAME", y="DAILY_READS", color="AVG_TAT_MINUTES",
                     color_continuous_scale="RdYlGn_r", title="Top 20 Radiologists by Daily Reads")
        fig.update_layout(height=400, margin=dict(t=40, b=10), xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)

elif page == "AI Summary":
    st.title("AI Report Extraction")
    st.markdown("Select a study to extract structured findings using Cortex AI:")
    if st.button("Extract Findings from Latest CT Study", type="primary"):
        with st.spinner("Cortex AI extracting structured findings..."):
            try:
                report = session.sql("""
                    SELECT REPORT_TEXT FROM HEALTHCARE_RADIOLOGY.RAW.REPORTS
                    WHERE STATUS = 'FINAL' ORDER BY FINALIZED_AT DESC LIMIT 1
                """).collect()
                if report:
                    text = report[0][0]
                    prompt = f"Extract structured findings from this radiology report as JSON with keys: modality, body_part, findings (array of type/description), impression, critical (boolean), urgency. Report: {text}"
                    safe = prompt.replace("'", "''")
                    result = session.sql(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5', '{safe}')").collect()[0][0]
                    st.markdown("**Extracted Findings:**")
                    st.code(str(result)[:2000], language="json")
            except Exception as e:
                st.error(f"Error: {e}")

elif page == "Ask Radiology":
    st.title("Ask the Data")
    st.markdown("Natural language questions powered by Cortex Analyst:")
    sample_qs = ["What is the average TAT for CT this month?", "How many critical findings are unacknowledged?", "Which radiologist has the highest reads per day?"]
    sel_q = st.selectbox("Sample:", [""] + sample_qs)
    user_q = st.text_input("Or type your question:") or sel_q
    if user_q:
        with st.spinner("Generating answer..."):
            try:
                request_body = {"messages": [{"role": "user", "content": [{"type": "text", "text": user_q}]}], "semantic_view": "HEALTHCARE_RADIOLOGY.AI.RADIOLOGY_SEMANTIC_VIEW"}
                resp = _snowflake.send_snow_api_request("POST", "/api/v2/cortex/analyst/message", {}, {}, request_body, None, 30000)
                parsed = json.loads(resp["content"])
                if resp["status"] < 400:
                    for block in parsed.get("message", {}).get("content", []):
                        if block.get("type") == "text":
                            st.markdown(block.get("text", ""))
                        elif block.get("type") == "sql":
                            sql = block.get("statement", "")
                            with st.expander("SQL"):
                                st.code(sql, language="sql")
                            try:
                                st.dataframe(session.sql(sql).to_pandas(), use_container_width=True)
                            except:
                                pass
            except Exception as e:
                st.error(f"Error: {e}")

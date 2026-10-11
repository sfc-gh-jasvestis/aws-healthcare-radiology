import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  departments: {
    match: /breach|department|worst|highest|volume|behind|plan|review/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, COMPLETED_COUNT, PLANNED_STUDIES_90D, ROUND(VOLUME_VS_PLAN_PCT, 1) AS VOLUME_VS_PLAN_PCT,
       ESCALATION_COUNT, BREACH_COUNT, REVIEW_COUNT, ROUND(QA_COMPLIANCE_PCT, 1) AS QA_COMPLIANCE_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY BREACH_COUNT DESC) <= 3
ORDER BY BREACH_COUNT DESC, ESCALATION_COUNT DESC`,
  },
  drivers: {
    match: /driver|escalation|cause|type|why|bottleneck/i,
    sql: `SELECT DELAY_DRIVER, ESCALATION_COUNT, BREACH_COUNT, REVIEW_COUNT, DEPTS_AFFECTED, ROUND(ESCALATION_CONFIRM_PCT, 1) AS ESCALATION_CONFIRM_PCT
FROM CURATED.DRIVER_SUMMARY ORDER BY BREACH_COUNT DESC LIMIT 7`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Study volume vs plan = studies completed / planned studies for the 90-day window. ' +
  'Escalation confirmation rate = worklist escalations confirmed as priority-study turnaround (TAT) breaches / escalations raised. ' +
  'A breach review is opened after a confirmed TAT breach. ' +
  'Area PACS outage escalations hit every department in a Singapore planning area at once and are never confirmed. ' +
  'All data is synthetic, department-level demo data with no patient records, images or report text. Do not give medical, diagnostic or clinical advice.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a radiology operations analyst. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, departments, drivers, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.departments.sql),
        executeQuery(INTENTS.drivers.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(BREACH_PROB_7D, 2) AS BREACH_PROB_7D, RISK_BAND
FROM ML.BREACH_RISK_SCORES ORDER BY BREACH_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS DEPARTMENTS FROM ML.BREACH_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topBreachDepartments: departments, delayDrivers: drivers, top5ByRisk: risk, departmentsPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short operational action memo for the Director of Radiology Operations at Harbourline Imaging, a fictional Singapore imaging network, with 3 prioritised workflow actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}

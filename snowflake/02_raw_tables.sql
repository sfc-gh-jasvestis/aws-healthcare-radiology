-- Radiology Analytics: Raw Tables with Synthetic Data
USE DATABASE HEALTHCARE_RADIOLOGY;
USE SCHEMA RAW;

-- Radiologists (50 named readers)
CREATE OR REPLACE TABLE RADIOLOGISTS (
    RADIOLOGIST_ID VARCHAR(20),
    FULL_NAME VARCHAR(100),
    SUBSPECIALTY VARCHAR(50),
    YEARS_EXPERIENCE INT,
    SHIFT VARCHAR(20),
    DAILY_TARGET INT,
    HIRE_DATE DATE
);

INSERT INTO RADIOLOGISTS
SELECT
    'RAD-' || LPAD(SEQ4()::VARCHAR, 3, '0'),
    CASE SEQ4() % 50
        WHEN 0 THEN 'Dr. Tanaka' WHEN 1 THEN 'Dr. Patel' WHEN 2 THEN 'Dr. Smith'
        WHEN 3 THEN 'Dr. Johnson' WHEN 4 THEN 'Dr. Williams' WHEN 5 THEN 'Dr. Chen'
        WHEN 6 THEN 'Dr. Garcia' WHEN 7 THEN 'Dr. Martinez' WHEN 8 THEN 'Dr. Lee'
        WHEN 9 THEN 'Dr. Kim' WHEN 10 THEN 'Dr. Nguyen' WHEN 11 THEN 'Dr. Brown'
        WHEN 12 THEN 'Dr. Davis' WHEN 13 THEN 'Dr. Wilson' WHEN 14 THEN 'Dr. Anderson'
        WHEN 15 THEN 'Dr. Thomas' WHEN 16 THEN 'Dr. Taylor' WHEN 17 THEN 'Dr. Moore'
        WHEN 18 THEN 'Dr. Jackson' WHEN 19 THEN 'Dr. Martin' WHEN 20 THEN 'Dr. White'
        WHEN 21 THEN 'Dr. Harris' WHEN 22 THEN 'Dr. Clark' WHEN 23 THEN 'Dr. Lewis'
        WHEN 24 THEN 'Dr. Robinson' WHEN 25 THEN 'Dr. Walker' WHEN 26 THEN 'Dr. Young'
        WHEN 27 THEN 'Dr. Allen' WHEN 28 THEN 'Dr. King' WHEN 29 THEN 'Dr. Wright'
        WHEN 30 THEN 'Dr. Scott' WHEN 31 THEN 'Dr. Torres' WHEN 32 THEN 'Dr. Hill'
        WHEN 33 THEN 'Dr. Green' WHEN 34 THEN 'Dr. Adams' WHEN 35 THEN 'Dr. Baker'
        WHEN 36 THEN 'Dr. Gonzalez' WHEN 37 THEN 'Dr. Nelson' WHEN 38 THEN 'Dr. Carter'
        WHEN 39 THEN 'Dr. Mitchell' WHEN 40 THEN 'Dr. Perez' WHEN 41 THEN 'Dr. Roberts'
        WHEN 42 THEN 'Dr. Turner' WHEN 43 THEN 'Dr. Phillips' WHEN 44 THEN 'Dr. Campbell'
        WHEN 45 THEN 'Dr. Parker' WHEN 46 THEN 'Dr. Evans' WHEN 47 THEN 'Dr. Edwards'
        WHEN 48 THEN 'Dr. Collins' WHEN 49 THEN 'Dr. Stewart'
    END,
    CASE SEQ4() % 5
        WHEN 0 THEN 'Neuroradiology' WHEN 1 THEN 'Body Imaging'
        WHEN 2 THEN 'Musculoskeletal' WHEN 3 THEN 'Chest' ELSE 'Interventional'
    END,
    5 + MOD(SEQ4() * 7, 25),
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Day' WHEN 1 THEN 'Evening' ELSE 'Night' END,
    CASE WHEN SEQ4() = 0 THEN 45 ELSE 25 + MOD(SEQ4() * 3, 20) END,
    DATEADD(DAY, -MOD(SEQ4() * 137, 3650), '2026-01-01')
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- Studies (50K)
CREATE OR REPLACE TABLE STUDIES (
    STUDY_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    RADIOLOGIST_ID VARCHAR(20),
    MODALITY VARCHAR(20),
    BODY_PART VARCHAR(50),
    PRIORITY VARCHAR(20),
    ORDER_TIME TIMESTAMP_NTZ,
    ACQUISITION_TIME TIMESTAMP_NTZ,
    REPORT_TIME TIMESTAMP_NTZ,
    STATUS VARCHAR(20),
    REFERRING_PHYSICIAN VARCHAR(100),
    FACILITY VARCHAR(50)
);

INSERT INTO STUDIES
SELECT
    'STD-' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    'PAT-' || LPAD(MOD(SEQ4() * 7, 20000)::VARCHAR, 6, '0'),
    'RAD-' || LPAD(MOD(SEQ4(), 50)::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'CT' WHEN 1 THEN 'MRI' WHEN 2 THEN 'X-Ray'
        WHEN 3 THEN 'Ultrasound' ELSE 'PET'
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Head' WHEN 1 THEN 'Chest' WHEN 2 THEN 'Abdomen'
        WHEN 3 THEN 'Spine' WHEN 4 THEN 'Extremity' WHEN 5 THEN 'Pelvis'
        WHEN 6 THEN 'Neck' ELSE 'Cardiac'
    END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'STAT' WHEN 1 THEN 'Urgent' ELSE 'Routine' END,
    DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600), '2026-05-01 00:00:00'),
    DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600) + 30 + MOD(SEQ4() * 3, 60), '2026-05-01 00:00:00'),
    CASE
        WHEN MOD(SEQ4(), 5) = 0 THEN
            DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600) + 285 + MOD(SEQ4() * 11, 180), '2026-05-01 00:00:00')
        WHEN MOD(SEQ4(), 5) = 1 THEN
            DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600) + 180 + MOD(SEQ4() * 11, 120), '2026-05-01 00:00:00')
        ELSE
            DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600) + 60 + MOD(SEQ4() * 11, 90), '2026-05-01 00:00:00')
    END,
    CASE WHEN MOD(SEQ4(), 20) = 0 THEN 'In Progress' ELSE 'Completed' END,
    'Dr. Ref-' || LPAD(MOD(SEQ4() * 13, 200)::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Main Hospital' WHEN 1 THEN 'Outpatient Center' ELSE 'Emergency Dept' END
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- Reports (45K — linked to completed studies)
CREATE OR REPLACE TABLE REPORTS (
    REPORT_ID VARCHAR(20),
    STUDY_ID VARCHAR(20),
    RADIOLOGIST_ID VARCHAR(20),
    REPORT_TEXT TEXT,
    IMPRESSION TEXT,
    FINDINGS_COUNT INT,
    REPORT_STATUS VARCHAR(20),
    CREATED_AT TIMESTAMP_NTZ
);

INSERT INTO REPORTS
SELECT
    'RPT-' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    'STD-' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    'RAD-' || LPAD(MOD(SEQ4(), 50)::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'CT HEAD WITHOUT CONTRAST: No acute intracranial hemorrhage. No midline shift. Ventricles are normal in size. No mass effect. Mild chronic microvascular ischemic changes noted in the periventricular white matter.'
        WHEN 1 THEN 'CT CHEST WITH CONTRAST: 2.3cm spiculated nodule in the right upper lobe suspicious for malignancy. Mediastinal lymphadenopathy measuring up to 1.8cm. No pleural effusion. Heart size is normal.'
        WHEN 2 THEN 'MRI BRAIN WITH AND WITHOUT CONTRAST: 1.5cm enhancing lesion in the left temporal lobe with surrounding edema. Differential includes metastasis vs high-grade glioma. Recommend neurosurgical consultation.'
        WHEN 3 THEN 'CHEST X-RAY PA AND LATERAL: Bilateral lower lobe infiltrates consistent with pneumonia. Small left pleural effusion. No pneumothorax. Cardiac silhouette is borderline enlarged.'
        WHEN 4 THEN 'ULTRASOUND ABDOMEN: Gallbladder contains multiple stones, largest measuring 1.2cm. No gallbladder wall thickening or pericholecystic fluid. Common bile duct measures 4mm, within normal limits.'
        ELSE 'CT ABDOMEN AND PELVIS WITH CONTRAST: No acute intra-abdominal pathology. Liver, spleen, pancreas, and adrenal glands are unremarkable. Kidneys enhance symmetrically. No free fluid.'
    END,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'No acute findings.' WHEN 1 THEN 'Findings suspicious for malignancy. Recommend follow-up.'
        WHEN 2 THEN 'Acute finding requiring clinical correlation.' ELSE 'Stable compared to prior study.'
    END,
    1 + MOD(SEQ4() * 3, 5),
    'Final',
    DATEADD(MINUTE, -MOD(SEQ4() * 17, 525600) + 200, '2026-05-01 00:00:00')
FROM TABLE(GENERATOR(ROWCOUNT => 45000));

-- Critical Findings (3K)
CREATE OR REPLACE TABLE CRITICAL_FINDINGS (
    FINDING_ID VARCHAR(20),
    STUDY_ID VARCHAR(20),
    RADIOLOGIST_ID VARCHAR(20),
    FINDING_TYPE VARCHAR(100),
    SEVERITY VARCHAR(20),
    DESCRIPTION TEXT,
    IDENTIFIED_AT TIMESTAMP_NTZ,
    ACKNOWLEDGED BOOLEAN,
    ACKNOWLEDGED_BY VARCHAR(100),
    ACKNOWLEDGED_AT TIMESTAMP_NTZ,
    COMMUNICATION_METHOD VARCHAR(30)
);

INSERT INTO CRITICAL_FINDINGS
SELECT
    'CF-' || LPAD(SEQ4()::VARCHAR, 5, '0'),
    'STD-' || LPAD(MOD(SEQ4() * 7, 50000)::VARCHAR, 6, '0'),
    'RAD-' || LPAD(MOD(SEQ4(), 50)::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Pulmonary Embolism' WHEN 1 THEN 'Intracranial Hemorrhage'
        WHEN 2 THEN 'Aortic Dissection' WHEN 3 THEN 'Pneumothorax'
        WHEN 4 THEN 'Bowel Obstruction' WHEN 5 THEN 'Stroke'
        WHEN 6 THEN 'Spinal Cord Compression' ELSE 'Tumor Mass Effect'
    END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Critical' WHEN 1 THEN 'Urgent' ELSE 'High' END,
    'Critical finding identified requiring immediate clinical attention and follow-up.',
    DATEADD(MINUTE, -MOD(SEQ4() * 23, 43200), '2026-05-01 00:00:00'),
    CASE WHEN MOD(SEQ4(), 100) < 72 THEN TRUE ELSE FALSE END,
    CASE WHEN MOD(SEQ4(), 100) < 72 THEN 'Dr. Ref-' || LPAD(MOD(SEQ4() * 13, 200)::VARCHAR, 3, '0') ELSE NULL END,
    CASE WHEN MOD(SEQ4(), 100) < 72 THEN DATEADD(MINUTE, -MOD(SEQ4() * 23, 43200) + 30 + MOD(SEQ4(), 60), '2026-05-01 00:00:00') ELSE NULL END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Phone' WHEN 1 THEN 'Page' ELSE 'Secure Message' END
FROM TABLE(GENERATOR(ROWCOUNT => 3000));

-- Equipment (30)
CREATE OR REPLACE TABLE EQUIPMENT (
    EQUIPMENT_ID VARCHAR(20),
    EQUIPMENT_NAME VARCHAR(100),
    MODALITY VARCHAR(20),
    MANUFACTURER VARCHAR(50),
    MODEL VARCHAR(50),
    INSTALL_DATE DATE,
    LAST_MAINTENANCE DATE,
    STATUS VARCHAR(20),
    LOCATION VARCHAR(50),
    DAILY_CAPACITY INT
);

INSERT INTO EQUIPMENT
SELECT
    'EQ-' || LPAD(SEQ4()::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'CT Scanner ' WHEN 1 THEN 'MRI Unit '
        WHEN 2 THEN 'X-Ray Room ' WHEN 3 THEN 'Ultrasound '
        ELSE 'PET/CT '
    END || (SEQ4() + 1)::VARCHAR,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'CT' WHEN 1 THEN 'MRI' WHEN 2 THEN 'X-Ray'
        WHEN 3 THEN 'Ultrasound' ELSE 'PET'
    END,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Siemens' WHEN 1 THEN 'GE Healthcare'
        WHEN 2 THEN 'Philips' ELSE 'Canon Medical'
    END,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'SOMATOM Force' WHEN 1 THEN 'Revolution Apex'
        WHEN 2 THEN 'Ingenia Ambition' ELSE 'Aquilion ONE'
    END,
    DATEADD(DAY, -MOD(SEQ4() * 137, 2555), '2026-01-01'),
    DATEADD(DAY, -MOD(SEQ4() * 37, 90), '2026-05-01'),
    CASE WHEN MOD(SEQ4(), 10) = 0 THEN 'Maintenance' ELSE 'Operational' END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Main Hospital' WHEN 1 THEN 'Outpatient Center' ELSE 'Emergency Dept' END,
    40 + MOD(SEQ4() * 7, 60)
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- Radiology Guidelines (80 documents for Cortex Search)
CREATE OR REPLACE TABLE RADIOLOGY_GUIDELINES (
    GUIDELINE_ID VARCHAR(20),
    TITLE VARCHAR(200),
    CATEGORY VARCHAR(50),
    CONTENT TEXT,
    EFFECTIVE_DATE DATE,
    VERSION VARCHAR(10),
    APPROVED_BY VARCHAR(100)
);

INSERT INTO RADIOLOGY_GUIDELINES
SELECT
    'GL-' || LPAD(SEQ4()::VARCHAR, 3, '0'),
    CASE MOD(SEQ4(), 16)
        WHEN 0 THEN 'CT Contrast Administration Protocol'
        WHEN 1 THEN 'MRI Safety Screening Checklist'
        WHEN 2 THEN 'Critical Findings Communication Policy'
        WHEN 3 THEN 'Radiation Dose Optimization Guidelines'
        WHEN 4 THEN 'Pediatric Imaging Protocols'
        WHEN 5 THEN 'Emergency Imaging Triage Criteria'
        WHEN 6 THEN 'Breast Imaging Reporting (BI-RADS)'
        WHEN 7 THEN 'Lung Nodule Follow-up (Fleischner)'
        WHEN 8 THEN 'Stroke Protocol Activation Criteria'
        WHEN 9 THEN 'Incidental Findings Management'
        WHEN 10 THEN 'MRI Contrast Agent Selection'
        WHEN 11 THEN 'CT Pulmonary Angiography Protocol'
        WHEN 12 THEN 'Ultrasound Thyroid Nodule (TI-RADS)'
        WHEN 13 THEN 'Spine MRI Ordering Guidelines'
        WHEN 14 THEN 'Nuclear Medicine Safety Standards'
        ELSE 'Quality Assurance Audit Procedures'
    END || ' v' || (1 + MOD(SEQ4(), 5))::VARCHAR,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Protocol' WHEN 1 THEN 'Safety' WHEN 2 THEN 'Communication'
        WHEN 3 THEN 'Dose Optimization' WHEN 4 THEN 'Pediatrics'
        WHEN 5 THEN 'Emergency' WHEN 6 THEN 'Reporting' ELSE 'Quality'
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'CONTRAST ADMINISTRATION: Verify eGFR within 30 days for patients over 60. Use low-osmolar non-ionic contrast (Iohexol 300mgI/mL). Standard dose: 1.5mL/kg up to 150mL. Pre-medicate with methylprednisolone for prior reactions. Hold metformin 48 hours post-contrast. Monitor for 30 minutes post-injection. Ensure crash cart availability. Document lot number and volume administered.'
        WHEN 1 THEN 'MRI SAFETY: Screen all patients for ferromagnetic implants, pacemakers, cochlear implants, and metallic foreign bodies. Zone IV access requires MRI-trained personnel only. Quench button location must be visible. No ferromagnetic equipment past 5-gauss line. Patient monitoring required for sedated patients. Remove all jewelry, hairpins, and clothing with metal components before entering scan room.'
        WHEN 2 THEN 'CRITICAL FINDINGS: All critical findings must be communicated directly to the ordering physician or covering provider within 60 minutes of identification. Document communication including: time of finding, time of communication, name and role of person notified, read-back confirmation. If unable to reach provider within 30 minutes, escalate to department chief. Maintain communication log for audit purposes.'
        WHEN 3 THEN 'RADIATION DOSE: Apply ALARA principle to all ionizing radiation studies. Use size-specific dose estimates (SSDE) for CT. Pediatric protocols must reduce dose by minimum 25% from adult. Track cumulative dose for patients with >3 CT scans annually. DLP targets: Head CT <1000 mGy*cm, Chest CT <400 mGy*cm, Abdomen CT <700 mGy*cm. Report dose alerts exceeding reference levels.'
        WHEN 4 THEN 'PEDIATRIC IMAGING: Weight-based protocols mandatory for all patients under 18. Prefer ultrasound and MRI over CT when clinically appropriate. Image Gently principles apply. Parental consent required for contrast administration. Child life specialist recommended for patients under 7. Immobilization devices preferred over sedation. Gonadal shielding when possible without compromising diagnostic quality.'
        WHEN 5 THEN 'EMERGENCY TRIAGE: STAT orders processed within 15 minutes of receipt. Stroke protocol: door-to-CT target <25 minutes. Trauma activation: whole-body CT initiated within 10 minutes. STEMI: CTA completed within 30 minutes. Aortic emergency: immediate scanner access. All emergency reads communicated verbally. Preliminary reports within 30 minutes for STAT studies.'
        WHEN 6 THEN 'STRUCTURED REPORTING: Use standardized templates for all modalities. Include clinical indication, technique, comparison studies, findings (organized by organ system), and impression. BI-RADS categories 0-6 for breast imaging. LI-RADS categories for liver lesions. PI-RADS for prostate MRI. TI-RADS for thyroid nodules. Lung-RADS for screening CT. Include measurements for all significant findings.'
        ELSE 'QUALITY ASSURANCE: Monthly peer review of minimum 5% of cases per radiologist. Track discordance rates (major and minor). Annual credentialing review. Equipment QC per ACR standards. Reject/repeat analysis monthly (target <5%). Patient satisfaction surveys quarterly. Turnaround time monitoring with SLA targets. Critical findings communication audit annually.'
    END,
    DATEADD(DAY, -MOD(SEQ4() * 47, 730), '2026-05-01'),
    (1 + MOD(SEQ4(), 5))::VARCHAR || '.0',
    'Dr. Tanaka, Chief Radiologist'
FROM TABLE(GENERATOR(ROWCOUNT => 80));

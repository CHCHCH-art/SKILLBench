#!/bin/bash
set -euo pipefail

INPUT_POP="/root/population.pdf"
INPUT_INCOME="/root/income.xlsx"
OUTPUT="/root/demographic_analysis.xlsx"

WORK="/tmp/demographic_alt"
JAVA_LIB="$WORK/lib"
JAVA_CLASSES="$WORK/classes"

MAVEN_REPO="/root/.cache/demographic-maven"

POI_VERSION="5.5.1"

rm -rf "$WORK"
mkdir -p "$WORK" "$JAVA_LIB" "$JAVA_CLASSES" "$MAVEN_REPO"
rm -f "$OUTPUT"

if [ ! -r "$INPUT_POP" ]; then
    echo "ERROR: cannot read $INPUT_POP" >&2
    exit 1
fi

if [ ! -r "$INPUT_INCOME" ]; then
    echo "ERROR: cannot read $INPUT_INCOME" >&2
    exit 1
fi

packages=()

if ! command -v javac >/dev/null 2>&1; then
    packages+=(default-jdk-headless)
fi

if ! command -v mvn >/dev/null 2>&1; then
    packages+=(maven)
fi

if [ "${#packages[@]}" -gt 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        "${packages[@]}"
    rm -rf /var/lib/apt/lists/*
fi

python3 <<'PYTHON_CHECK'
missing = []

try:
    import pdfplumber
except ImportError:
    missing.append("pdfplumber")

try:
    import openpyxl
except ImportError:
    missing.append("openpyxl")

if missing:
    raise SystemExit(
        "ERROR: missing Python package(s): "
        + ", ".join(missing)
        + ". Install them before running this script."
    )
PYTHON_CHECK


python3 <<'PYTHON_ETL'
import csv
import math
import os
import re
import sqlite3

import pdfplumber
from openpyxl import load_workbook

POP_PATH = "/root/population.pdf"
INCOME_PATH = "/root/income.xlsx"
DB_PATH = "/tmp/demographic_alt/staging.sqlite"
TSV_PATH = "/tmp/demographic_alt/source.tsv"


def clean_text(value):
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip()


def parse_number(value):
    if value is None:
        return None

    if isinstance(value, bool):
        return float(int(value))

    if isinstance(value, (int, float)):
        if isinstance(value, float) and math.isnan(value):
            return None
        return float(value)

    s = str(value).strip()

    if not s or s.lower() in {
        "na",
        "n/a",
        "nan",
        "none",
        "null",
        "-",
    }:
        return None

    negative = s.startswith("(") and s.endswith(")")
    if negative:
        s = s[1:-1]

    s = (
        s.replace(",", "")
        .replace("$", "")
        .replace(" ", "")
    )

    try:
        n = float(s)
    except ValueError:
        return None

    return -n if negative else n


def parse_code(value):
    n = parse_number(value)

    if n is None or not math.isfinite(n):
        return None

    rounded = round(n)

    if abs(n - rounded) > 1e-9:
        return None

    return int(rounded)


def percentile_linear(sorted_values, p):
    """
    Match pandas Series.quantile() default linear interpolation.
    """
    n = len(sorted_values)

    if n == 0:
        raise ValueError(
            "Cannot compute quartiles: no MEDIAN_INCOME values"
        )

    if n == 1:
        return float(sorted_values[0])

    pos = (n - 1) * p
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))

    if lo == hi:
        return float(sorted_values[lo])

    frac = pos - lo

    return float(
        sorted_values[lo]
        + (sorted_values[hi] - sorted_values[lo]) * frac
    )


population_rows = []
seq = 0

with pdfplumber.open(POP_PATH) as pdf:
    for page in pdf.pages:
        for table in page.extract_tables() or []:
            for row in table or []:
                if not row or len(row) < 4:
                    continue

                code = parse_code(row[0])
                pop = parse_number(row[3])

                if code is None or pop is None:
                    continue

                name = clean_text(row[1])
                state = clean_text(row[2])

                if not state:
                    continue

                population_rows.append(
                    (
                        seq,
                        code,
                        name,
                        state,
                        int(round(pop)),
                    )
                )

                seq += 1

if not population_rows:
    raise RuntimeError(
        "No population data rows could be extracted "
        "from /root/population.pdf"
    )


wb = load_workbook(
    INCOME_PATH,
    read_only=True,
    data_only=True,
)

required = {
    "SA2_CODE",
    "EARNERS",
    "MEDIAN_INCOME",
    "MEAN_INCOME",
}

income_rows = []
found_sheet = None

for ws in wb.worksheets:
    first = next(
        ws.iter_rows(
            min_row=1,
            max_row=1,
            values_only=True,
        ),
        None,
    )

    if first is None:
        continue

    headers = {
        re.sub(r"\s+", "_", clean_text(v)).upper(): idx
        for idx, v in enumerate(first)
        if clean_text(v)
    }

    if not required.issubset(headers):
        continue

    found_sheet = ws.title
    seq = 0

    for values in ws.iter_rows(
        min_row=2,
        values_only=True,
    ):
        code_idx = headers["SA2_CODE"]
        earners_idx = headers["EARNERS"]
        median_idx = headers["MEDIAN_INCOME"]
        mean_idx = headers["MEAN_INCOME"]

        code = parse_code(
            values[code_idx]
            if code_idx < len(values)
            else None
        )

        if code is None:
            continue

        earners = parse_number(
            values[earners_idx]
            if earners_idx < len(values)
            else None
        )

        median = parse_number(
            values[median_idx]
            if median_idx < len(values)
            else None
        )

        mean = parse_number(
            values[mean_idx]
            if mean_idx < len(values)
            else None
        )

        income_rows.append(
            (
                seq,
                code,
                earners,
                median,
                mean,
            )
        )

        seq += 1

    break

wb.close()

if found_sheet is None:
    raise RuntimeError(
        "No worksheet in /root/income.xlsx contains "
        "the required income columns"
    )

if not income_rows:
    raise RuntimeError(
        "No income data rows could be read from "
        "/root/income.xlsx"
    )


if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)

try:
    conn.executescript(
        """
        CREATE TABLE population (
            seq INTEGER NOT NULL,
            SA2_CODE INTEGER NOT NULL,
            SA2_NAME TEXT,
            STATE TEXT,
            POPULATION_2023 INTEGER
        );

        CREATE TABLE income (
            seq INTEGER NOT NULL,
            SA2_CODE INTEGER NOT NULL,
            EARNERS REAL,
            MEDIAN_INCOME REAL,
            MEAN_INCOME REAL
        );

        CREATE INDEX idx_population_code
            ON population(SA2_CODE);

        CREATE INDEX idx_income_code
            ON income(SA2_CODE);
        """
    )

    conn.executemany(
        """
        INSERT INTO population(
            seq,
            SA2_CODE,
            SA2_NAME,
            STATE,
            POPULATION_2023
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        population_rows,
    )

    conn.executemany(
        """
        INSERT INTO income(
            seq,
            SA2_CODE,
            EARNERS,
            MEDIAN_INCOME,
            MEAN_INCOME
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        income_rows,
    )

    conn.executescript(
        """
        CREATE TABLE joined AS
        SELECT
            p.seq AS population_seq,
            i.seq AS income_seq,
            p.SA2_CODE AS SA2_CODE,
            p.SA2_NAME AS SA2_NAME,
            p.STATE AS STATE,
            p.POPULATION_2023 AS POPULATION_2023,
            i.EARNERS AS EARNERS,
            i.MEDIAN_INCOME AS MEDIAN_INCOME,
            i.MEAN_INCOME AS MEAN_INCOME,
            CAST(NULL AS TEXT) AS Quarter,
            CAST(NULL AS REAL) AS Total
        FROM population p
        INNER JOIN income i
            ON i.SA2_CODE = p.SA2_CODE;
        """
    )

    medians = [
        float(row[0])
        for row in conn.execute(
            """
            SELECT MEDIAN_INCOME
            FROM joined
            WHERE MEDIAN_INCOME IS NOT NULL
            ORDER BY MEDIAN_INCOME
            """
        )
    ]

    q1 = percentile_linear(medians, 0.25)
    q2 = percentile_linear(medians, 0.50)
    q3 = percentile_linear(medians, 0.75)

    conn.execute(
        """
        UPDATE joined
        SET
            Quarter = CASE
                WHEN MEDIAN_INCOME IS NULL THEN 'Q1'
                WHEN MEDIAN_INCOME <= ? THEN 'Q1'
                WHEN MEDIAN_INCOME <= ? THEN 'Q2'
                WHEN MEDIAN_INCOME <= ? THEN 'Q3'
                ELSE 'Q4'
            END,

            Total = CASE
                WHEN EARNERS IS NULL
                  OR MEDIAN_INCOME IS NULL
                    THEN NULL
                ELSE EARNERS * MEDIAN_INCOME
            END
        """,
        (q1, q2, q3),
    )

    conn.commit()

    joined_count = conn.execute(
        "SELECT COUNT(*) FROM joined"
    ).fetchone()[0]

    if joined_count == 0:
        raise RuntimeError(
            "The SA2_CODE inner join produced no rows"
        )

    headers = [
        "SA2_CODE",
        "SA2_NAME",
        "STATE",
        "POPULATION_2023",
        "EARNERS",
        "MEDIAN_INCOME",
        "MEAN_INCOME",
        "Quarter",
        "Total",
    ]

    query = """
        SELECT
            SA2_CODE,
            SA2_NAME,
            STATE,
            POPULATION_2023,
            EARNERS,
            MEDIAN_INCOME,
            MEAN_INCOME,
            Quarter,
            Total
        FROM joined
        ORDER BY population_seq, income_seq
    """

    with open(
        TSV_PATH,
        "w",
        encoding="utf-8",
        newline="",
    ) as f:
        writer = csv.writer(
            f,
            delimiter="\t",
            lineterminator="\n",
        )

        writer.writerow(headers)

        for row in conn.execute(query):
            writer.writerow(
                [
                    "" if value is None else value
                    for value in row
                ]
            )

    print(
        f"ETL complete: "
        f"{len(population_rows)} population rows, "
        f"{len(income_rows)} income rows, "
        f"{joined_count} joined rows"
    )
    print(
        f"Income quartile boundaries: "
        f"{q1:.2f}, {q2:.2f}, {q3:.2f}"
    )

finally:
    conn.close()
PYTHON_ETL


cat > "$WORK/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="
             http://maven.apache.org/POM/4.0.0
             https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <groupId>local.demographic</groupId>
    <artifactId>demographic-builder</artifactId>
    <version>1.0.0</version>

    <dependencies>

        <!--
            POI runtime itself.

            poi-ooxml normally pulls in poi-ooxml-lite.
            We deliberately exclude it and use poi-ooxml-full below so the
            complete ECMA-376 schema set is available.
        -->
        <dependency>
            <groupId>org.apache.poi</groupId>
            <artifactId>poi-ooxml</artifactId>
            <version>${POI_VERSION}</version>

            <exclusions>
                <exclusion>
                    <groupId>org.apache.poi</groupId>
                    <artifactId>poi-ooxml-lite</artifactId>
                </exclusion>
            </exclusions>
        </dependency>

        <!--
            Complete OOXML schema set.

            Keep this on exactly the same version as poi-ooxml.
            Its matching XMLBeans dependency is resolved transitively by Maven.
        -->
        <dependency>
            <groupId>org.apache.poi</groupId>
            <artifactId>poi-ooxml-full</artifactId>
            <version>${POI_VERSION}</version>
        </dependency>

    </dependencies>

</project>
EOF

echo "Resolving isolated Apache POI ${POI_VERSION} dependencies..."

rm -rf "$JAVA_LIB"
mkdir -p "$JAVA_LIB"

mvn \
    --batch-mode \
    --no-transfer-progress \
    -f "$WORK/pom.xml" \
    -Dmaven.repo.local="$MAVEN_REPO" \
    dependency:copy-dependencies \
    -DincludeScope=runtime \
    -DoutputDirectory="$JAVA_LIB"


if ! compgen -G \
    "$JAVA_LIB/poi-${POI_VERSION}.jar" \
    >/dev/null
then
    echo \
        "ERROR: poi-${POI_VERSION}.jar was not resolved" \
        >&2
    exit 1
fi

if ! compgen -G \
    "$JAVA_LIB/poi-ooxml-${POI_VERSION}.jar" \
    >/dev/null
then
    echo \
        "ERROR: poi-ooxml-${POI_VERSION}.jar was not resolved" \
        >&2
    exit 1
fi

if ! compgen -G \
    "$JAVA_LIB/poi-ooxml-full-${POI_VERSION}.jar" \
    >/dev/null
then
    echo \
        "ERROR: poi-ooxml-full-${POI_VERSION}.jar was not resolved" \
        >&2
    exit 1
fi

if ! compgen -G \
    "$JAVA_LIB/xmlbeans-*.jar" \
    >/dev/null
then
    echo \
        "ERROR: XMLBeans was not resolved" \
        >&2
    exit 1
fi

if compgen -G \
    "$JAVA_LIB/poi-ooxml-lite-*.jar" \
    >/dev/null
then
    echo \
        "ERROR: poi-ooxml-lite unexpectedly exists in the isolated classpath" \
        >&2

    ls -l "$JAVA_LIB"/poi-ooxml-lite-*.jar >&2
    exit 1
fi

echo "Resolved POI runtime:"
find "$JAVA_LIB" \
    -maxdepth 1 \
    -type f \
    \( \
        -name 'poi-*.jar' \
        -o -name 'xmlbeans-*.jar' \
    \) \
    -printf '  %f\n' \
    | sort


cat > "$WORK/DemographicBuilder.java" <<'JAVA_SOURCE'
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import org.apache.poi.ss.SpreadsheetVersion;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.DataConsolidateFunction;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.util.AreaReference;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.util.CellReference;
import org.apache.poi.xssf.usermodel.XSSFPivotTable;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.xmlbeans.XmlObject;


public class DemographicBuilder {

    private static final String SOURCE_TSV =
            "/tmp/demographic_alt/source.tsv";

    private static final String OUTPUT_XLSX =
            "/root/demographic_analysis.xlsx";

    private static final String EXPECTED_LIB_PATH =
            "/tmp/demographic_alt/lib/";


    private static double parseDouble(String value) {
        return Double.parseDouble(value.trim());
    }


    private static void assertLoadedFromIsolatedLib(
            String description,
            Class<?> type) {

        URL location = type
                .getProtectionDomain()
                .getCodeSource()
                .getLocation();

        if (location == null) {
            throw new IllegalStateException(
                    "Cannot determine code source for "
                    + description
                    + " ("
                    + type.getName()
                    + ")"
            );
        }

        String path = location.toString();

        if (!path.contains(EXPECTED_LIB_PATH)) {
            throw new IllegalStateException(
                    description
                    + " was loaded from an unexpected location: "
                    + path
            );
        }

        System.out.println(
                description + " loaded from: " + path
        );
    }


    private static XSSFPivotTable createPivot(
            XSSFSheet target,
            XSSFSheet source,
            int sourceLastExcelRow,
            int rowField,
            Integer colField,
            int dataField,
            DataConsolidateFunction function,
            String valueCaption) {

        AreaReference sourceArea = new AreaReference(
                "A1:I" + sourceLastExcelRow,
                SpreadsheetVersion.EXCEL2007
        );

        XSSFPivotTable pivot = target.createPivotTable(
                sourceArea,
                new CellReference("A3"),
                source
        );

        pivot.addRowLabel(rowField);

        if (colField != null) {
            pivot.addColLabel(colField.intValue());
        }

        pivot.addColumnLabel(
                function,
                dataField,
                valueCaption
        );

        return pivot;
    }


    public static void main(String[] args) throws Exception {

        assertLoadedFromIsolatedLib(
                "Apache POI",
                XSSFWorkbook.class
        );

        assertLoadedFromIsolatedLib(
                "XMLBeans",
                XmlObject.class
        );

        Class<?> workbookSchemaClass = Class.forName(
                "org.openxmlformats.schemas."
                + "spreadsheetml.x2006.main.CTWorkbook"
        );

        assertLoadedFromIsolatedLib(
                "OOXML SpreadsheetML schema",
                workbookSchemaClass
        );


        try (XSSFWorkbook workbook = new XSSFWorkbook()) {

            XSSFSheet populationSheet =
                    workbook.createSheet("Population by State");

            XSSFSheet earnersSheet =
                    workbook.createSheet("Earners by State");

            XSSFSheet regionsSheet =
                    workbook.createSheet("Regions by State");

            XSSFSheet quartileSheet =
                    workbook.createSheet("State Income Quartile");

            XSSFSheet sourceSheet =
                    workbook.createSheet("SourceData");


            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerFont.setColor(
                    IndexedColors.WHITE.getIndex()
            );

            CellStyle headerStyle =
                    workbook.createCellStyle();

            headerStyle.setFont(headerFont);

            headerStyle.setFillForegroundColor(
                    IndexedColors.DARK_BLUE.getIndex()
            );

            headerStyle.setFillPattern(
                    FillPatternType.SOLID_FOREGROUND
            );


            CellStyle integerStyle =
                    workbook.createCellStyle();

            integerStyle.setDataFormat(
                    workbook
                            .createDataFormat()
                            .getFormat("#,##0")
            );


            CellStyle numberStyle =
                    workbook.createCellStyle();

            numberStyle.setDataFormat(
                    workbook
                            .createDataFormat()
                            .getFormat("#,##0.00")
            );


            int rowIndex = 0;

            try (
                    BufferedReader reader =
                            new BufferedReader(
                                    new InputStreamReader(
                                            new FileInputStream(
                                                    SOURCE_TSV
                                            ),
                                            StandardCharsets.UTF_8
                                    )
                            )
            ) {
                String line;

                while ((line = reader.readLine()) != null) {

                    String[] fields =
                            line.split("\\t", -1);

                    if (fields.length != 9) {
                        throw new IllegalStateException(
                                "Canonical source row has "
                                + fields.length
                                + " columns instead of 9 at row "
                                + (rowIndex + 1)
                        );
                    }

                    Row row =
                            sourceSheet.createRow(rowIndex);

                    for (int col = 0; col < 9; col++) {

                        Cell cell = row.createCell(col);
                        String value = fields[col];

                        if (rowIndex == 0) {
                            cell.setCellValue(value);
                            cell.setCellStyle(headerStyle);
                            continue;
                        }

                        if (value.isEmpty()) {
                            continue;
                        }

                        switch (col) {
                            case 0: // SA2_CODE
                                cell.setCellValue(value.trim());
                                break;


                            case 3: // POPULATION_2023
                            case 4: // EARNERS

                                cell.setCellValue(
                                        parseDouble(value)
                                );

                                cell.setCellStyle(
                                        integerStyle
                                );

                                break;


                            case 5: // MEDIAN_INCOME
                            case 6: // MEAN_INCOME
                            case 8: // Total

                                cell.setCellValue(
                                        parseDouble(value)
                                );

                                cell.setCellStyle(
                                        numberStyle
                                );

                                break;


                            default:

                                cell.setCellValue(value);
                                break;
                        }
                    }

                    rowIndex++;
                }
            }


            if (rowIndex <= 1) {
                throw new IllegalStateException(
                        "SourceData contains no data rows"
                );
            }


            int lastDataRowZeroBased =
                    rowIndex - 1;

            int lastExcelRow = rowIndex;


            sourceSheet.createFreezePane(0, 1);

            sourceSheet.setAutoFilter(
                    new CellRangeAddress(
                            0,
                            lastDataRowZeroBased,
                            0,
                            8
                    )
            );

            sourceSheet.setColumnWidth(
                    0,
                    14 * 256
            );

            sourceSheet.setColumnWidth(
                    1,
                    30 * 256
            );

            sourceSheet.setColumnWidth(
                    2,
                    18 * 256
            );

            for (int c = 3; c <= 8; c++) {
                sourceSheet.setColumnWidth(
                        c,
                        18 * 256
                );
            }


            createPivot(
                    populationSheet,
                    sourceSheet,
                    lastExcelRow,
                    2,
                    null,
                    3,
                    DataConsolidateFunction.SUM,
                    "Sum of POPULATION_2023"
            );


            createPivot(
                    earnersSheet,
                    sourceSheet,
                    lastExcelRow,
                    2,
                    null,
                    4,
                    DataConsolidateFunction.SUM,
                    "Sum of EARNERS"
            );


            createPivot(
                    regionsSheet,
                    sourceSheet,
                    lastExcelRow,
                    2,
                    null,
                    0,
                    DataConsolidateFunction.COUNT,
                    "Count of SA2_CODE"
            );


            createPivot(
                    quartileSheet,
                    sourceSheet,
                    lastExcelRow,
                    2,
                    Integer.valueOf(7),
                    4,
                    DataConsolidateFunction.SUM,
                    "Sum of EARNERS"
            );


            workbook.setForceFormulaRecalculation(true);


            try (
                    FileOutputStream out =
                            new FileOutputStream(
                                    OUTPUT_XLSX
                            )
            ) {
                workbook.write(out);
            }
        }


        System.out.println(
                "Workbook written: " + OUTPUT_XLSX
        );
    }
}
JAVA_SOURCE


javac \
    -proc:none \
    -encoding UTF-8 \
    -cp "$JAVA_LIB/*" \
    -d "$JAVA_CLASSES" \
    "$WORK/DemographicBuilder.java"


java \
    -cp "$JAVA_LIB/*:$JAVA_CLASSES" \
    DemographicBuilder


python3 <<'PYTHON_VERIFY'
import os
import zipfile
import xml.etree.ElementTree as ET


path = "/root/demographic_analysis.xlsx"

required_sheets = [
    "Population by State",
    "Earners by State",
    "Regions by State",
    "State Income Quartile",
    "SourceData",
]


if not os.path.isfile(path):
    raise RuntimeError(
        "Output workbook was not created"
    )

if os.path.getsize(path) == 0:
    raise RuntimeError(
        "Output workbook is empty"
    )


with zipfile.ZipFile(path) as zf:

    names_in_zip = set(zf.namelist())

    if "xl/workbook.xml" not in names_in_zip:
        raise RuntimeError(
            "Generated file has no xl/workbook.xml"
        )

    workbook_xml = ET.fromstring(
        zf.read("xl/workbook.xml")
    )

    ns = {
        "m":
            "http://schemas.openxmlformats.org/"
            "spreadsheetml/2006/main"
    }

    names = [
        node.attrib["name"]
        for node in workbook_xml.findall(
            "m:sheets/m:sheet",
            ns,
        )
    ]

    if names != required_sheets:
        raise RuntimeError(
            "Unexpected worksheet list/order: "
            f"{names}"
        )


    pivot_parts = sorted(
        name
        for name in zf.namelist()
        if name.startswith(
            "xl/pivotTables/pivotTable"
        )
        and name.endswith(".xml")
    )

    if len(pivot_parts) != 4:
        raise RuntimeError(
            "Expected exactly 4 OOXML pivot table "
            f"definitions, found {len(pivot_parts)}: "
            f"{pivot_parts}"
        )


    pivot_cache_definitions = sorted(
        name
        for name in zf.namelist()
        if name.startswith(
            "xl/pivotCache/pivotCacheDefinition"
        )
        and name.endswith(".xml")
    )

    if len(pivot_cache_definitions) < 4:
        raise RuntimeError(
            "Expected at least 4 pivot cache "
            "definitions, found "
            f"{len(pivot_cache_definitions)}"
        )


    source_sheet_parts = [
        name
        for name in zf.namelist()
        if name.startswith("xl/worksheets/sheet")
        and name.endswith(".xml")
    ]

    if len(source_sheet_parts) != 5:
        raise RuntimeError(
            "Expected 5 worksheet XML parts, found "
            f"{len(source_sheet_parts)}"
        )


print(
    "Verification passed:"
    "\n  workbook: /root/demographic_analysis.xlsx"
    "\n  worksheets: 5"
    "\n  native pivot tables: 4"
    "\n  pivot cache definitions: "
    f"{len(pivot_cache_definitions)}"
)
PYTHON_VERIFY


echo
echo "Done: $OUTPUT"
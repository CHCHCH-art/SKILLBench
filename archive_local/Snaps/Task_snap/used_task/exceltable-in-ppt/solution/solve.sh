#!/bin/bash
set -euo pipefail

INPUT_FILE="/root/input.pptx"
OUTPUT_FILE="/root/results.pptx"

WORK_DIR="/tmp/poi_pptx_rate_solution"
JAVA_FILE="${WORK_DIR}/SolvePptxRates.java"
JAVA_LIB="${WORK_DIR}/lib"
JAVA_CLASSES="${WORK_DIR}/classes"
MAVEN_REPO="/root/.cache/poi-maven"

UPDATED_XLSX="${WORK_DIR}/updated_embedding.xlsx"
UPDATED_OBJECT="${WORK_DIR}/updated_embedding_object.bin"
EMBED_NAME_FILE="${WORK_DIR}/embedding_name.txt"

POI_VERSION="5.5.1"
LOG4J_VERSION="2.24.3"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}" "${JAVA_LIB}" "${JAVA_CLASSES}" "${MAVEN_REPO}"
rm -f "${OUTPUT_FILE}"

if [ ! -f "${INPUT_FILE}" ]; then
    echo "ERROR: Input file not found: ${INPUT_FILE}" >&2
    exit 1
fi

packages=()
command -v javac >/dev/null 2>&1 || packages+=(default-jdk-headless)
command -v mvn >/dev/null 2>&1 || packages+=(maven)

if [ "${#packages[@]}" -gt 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
    rm -rf /var/lib/apt/lists/*
fi

echo "[1/5] Resolving isolated Apache POI ${POI_VERSION} dependencies..."

cat > "${WORK_DIR}/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>local</groupId>
    <artifactId>pptx-rate-solution</artifactId>
    <version>1.0.0</version>

    <dependencies>
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

        <dependency>
            <groupId>org.apache.poi</groupId>
            <artifactId>poi-ooxml-full</artifactId>
            <version>${POI_VERSION}</version>
        </dependency>

        <!-- Optional logging provider; removes the Log4j "no provider" warning. -->
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-core</artifactId>
            <version>${LOG4J_VERSION}</version>
        </dependency>
    </dependencies>
</project>
EOF

rm -rf "${JAVA_LIB}"
mkdir -p "${JAVA_LIB}"

mvn \
    --batch-mode \
    --no-transfer-progress \
    -f "${WORK_DIR}/pom.xml" \
    -Dmaven.repo.local="${MAVEN_REPO}" \
    dependency:copy-dependencies \
    -DincludeScope=runtime \
    -DoutputDirectory="${JAVA_LIB}"

for required in \
    "${JAVA_LIB}/poi-${POI_VERSION}.jar" \
    "${JAVA_LIB}/poi-ooxml-${POI_VERSION}.jar" \
    "${JAVA_LIB}/poi-ooxml-full-${POI_VERSION}.jar"
do
    if [ ! -f "${required}" ]; then
        echo "ERROR: Required dependency missing: ${required}" >&2
        exit 1
    fi
done

if ! compgen -G "${JAVA_LIB}/xmlbeans-*.jar" >/dev/null; then
    echo "ERROR: XMLBeans dependency was not resolved" >&2
    exit 1
fi

if compgen -G "${JAVA_LIB}/poi-ooxml-lite-*.jar" >/dev/null; then
    echo "ERROR: poi-ooxml-lite unexpectedly exists in isolated classpath" >&2
    ls -l "${JAVA_LIB}"/poi-ooxml-lite-*.jar >&2
    exit 1
fi

echo "Resolved POI/XMLBeans runtime:"
find "${JAVA_LIB}" -maxdepth 1 -type f \
    \( -name 'poi-*.jar' -o -name 'xmlbeans-*.jar' -o -name 'log4j-core-*.jar' \) \
    -printf '  %f\n' | sort

cat > "${JAVA_FILE}" <<'JAVA_SOURCE'
import org.apache.poi.openxml4j.opc.PackagePart;
import org.apache.poi.poifs.filesystem.DirectoryNode;
import org.apache.poi.poifs.filesystem.FileMagic;
import org.apache.poi.poifs.filesystem.POIFSFileSystem;
import org.apache.poi.sl.usermodel.ObjectMetaData;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.CellValue;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.FormulaEvaluator;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xslf.usermodel.XSLFGroupShape;
import org.apache.poi.xslf.usermodel.XSLFObjectData;
import org.apache.poi.xslf.usermodel.XSLFObjectShape;
import org.apache.poi.xslf.usermodel.XSLFShape;
import org.apache.poi.xslf.usermodel.XSLFSlide;
import org.apache.poi.xslf.usermodel.XSLFTextShape;
import org.apache.poi.xslf.usermodel.XMLSlideShow;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.xmlbeans.XmlObject;

import java.awt.geom.Rectangle2D;
import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.CodeSource;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class SolvePptxRates {

    private static final Pattern CURRENCY = Pattern.compile("^[A-Z]{3}$");

    private static final Pattern RATE_A = Pattern.compile(
        "(?i)\\b([A-Z]{3})\\b\\s*" +
        "(?:to|->|→|/)\\s*" +
        "\\b([A-Z]{3})\\b" +
        "[^0-9]{0,100}" +
        "([0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?\\d+)?)"
    );

    private static final Pattern RATE_B = Pattern.compile(
        "(?i)(?:\\b1(?:\\.0+)?\\s*)?" +
        "\\b([A-Z]{3})\\b\\s*=\\s*" +
        "([0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?\\d+)?)\\s*" +
        "\\b([A-Z]{3})\\b"
    );

    static class UpdateInfo {
        int slideIndex;
        String from;
        String to;
        double rate;
        String sourceText;
        Rectangle2D anchor;

        UpdateInfo(int slideIndex, String from, String to, double rate,
                   String sourceText, Rectangle2D anchor) {
            this.slideIndex = slideIndex;
            this.from = from;
            this.to = to;
            this.rate = rate;
            this.sourceText = sourceText;
            this.anchor = anchor;
        }
    }

    static class MatrixInfo {
        int sheetIndex;
        int headerRow;
        int rowLabelColumn;
        Map<String, Integer> currencyColumns;
        Map<String, Integer> currencyRows;
        int score;

        MatrixInfo(int sheetIndex, int headerRow, int rowLabelColumn,
                   Map<String, Integer> currencyColumns,
                   Map<String, Integer> currencyRows,
                   int score) {
            this.sheetIndex = sheetIndex;
            this.headerRow = headerRow;
            this.rowLabelColumn = rowLabelColumn;
            this.currencyColumns = currencyColumns;
            this.currencyRows = currencyRows;
            this.score = score;
        }

        boolean supports(String from, String to) {
            return currencyColumns.containsKey(from)
                && currencyColumns.containsKey(to)
                && currencyRows.containsKey(from)
                && currencyRows.containsKey(to);
        }
    }

    static class EmbeddedWorkbook {
        int slideIndex;
        String packagePartName;
        Rectangle2D anchor;
        byte[] workbookBytes;        // unwrapped XLSX bytes
        List<MatrixInfo> matrices;
        XSLFObjectShape objectShape; // non-null for normal OLE objects
        byte[] originalRawBytes;     // raw PPTX embedding part
        String oleEntryName;         // used only by package-level fallback

        EmbeddedWorkbook(int slideIndex,
                         String packagePartName,
                         Rectangle2D anchor,
                         byte[] workbookBytes,
                         List<MatrixInfo> matrices,
                         XSLFObjectShape objectShape,
                         byte[] originalRawBytes,
                         String oleEntryName) {
            this.slideIndex = slideIndex;
            this.packagePartName = packagePartName;
            this.anchor = anchor;
            this.workbookBytes = workbookBytes;
            this.matrices = matrices;
            this.objectShape = objectShape;
            this.originalRawBytes = originalRawBytes;
            this.oleEntryName = oleEntryName;
        }
    }

    static class Match {
        UpdateInfo update;
        EmbeddedWorkbook embedding;
        MatrixInfo matrix;
        double score;

        Match(UpdateInfo update, EmbeddedWorkbook embedding,
              MatrixInfo matrix, double score) {
            this.update = update;
            this.embedding = embedding;
            this.matrix = matrix;
            this.score = score;
        }
    }

    static class UnwrappedEmbedding {
        byte[] workbookBytes;
        String oleEntryName;

        UnwrappedEmbedding(byte[] workbookBytes, String oleEntryName) {
            this.workbookBytes = workbookBytes;
            this.oleEntryName = oleEntryName;
        }
    }

    private static byte[] readAll(InputStream in) throws IOException {
        try (InputStream input = in;
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[65536];
            int n;
            while ((n = input.read(buffer)) >= 0) {
                out.write(buffer, 0, n);
            }
            return out.toByteArray();
        }
    }

    private static boolean isZipPackage(byte[] data) {
        return data.length >= 4
            && data[0] == 'P'
            && data[1] == 'K'
            && data[2] == 3
            && data[3] == 4;
    }

    private static boolean isOle2(byte[] data) {
        byte[] sig = new byte[] {
            (byte)0xD0, (byte)0xCF, 0x11, (byte)0xE0,
            (byte)0xA1, (byte)0xB1, 0x1A, (byte)0xE1
        };
        return data.length >= sig.length
            && Arrays.equals(Arrays.copyOf(data, sig.length), sig);
    }

    private static String signature(byte[] data) {
        int n = Math.min(data.length, 8);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            if (i > 0) sb.append(' ');
            sb.append(String.format("%02X", data[i] & 0xff));
        }
        return sb.toString();
    }

    private static void assertLoadedFromExpectedLib(
        String description,
        Class<?> clazz
    ) throws Exception {
        String expectedDir = System.getProperty("expected.lib.dir");
        if (expectedDir == null || expectedDir.trim().isEmpty()) {
            throw new IllegalStateException("System property expected.lib.dir is not set");
        }

        CodeSource codeSource = clazz.getProtectionDomain().getCodeSource();
        if (codeSource == null || codeSource.getLocation() == null) {
            throw new IllegalStateException(
                "Cannot determine code source for " + description + ": " + clazz.getName()
            );
        }

        URL location = codeSource.getLocation();
        URI uri = location.toURI();
        Path expected = Paths.get(expectedDir).toAbsolutePath().normalize();
        Path actual = Paths.get(uri).toAbsolutePath().normalize();

        if (!actual.startsWith(expected)) {
            throw new IllegalStateException(
                description + " was loaded from an unexpected location.\n" +
                "Expected under: " + expected + "\n" +
                "Actually loaded from: " + actual
            );
        }

        System.out.println(description + " loaded from: " + actual);
    }

    private static void validatePoiRuntime() throws Exception {
        assertLoadedFromExpectedLib("Apache POI XSLF", XMLSlideShow.class);
        assertLoadedFromExpectedLib("Apache POI Workbook", WorkbookFactory.class);
        assertLoadedFromExpectedLib("XMLBeans", XmlObject.class);

        Class<?> presentationSchema = Class.forName(
            "org.openxmlformats.schemas.presentationml.x2006.main.SldMasterDocument"
        );
        assertLoadedFromExpectedLib("PresentationML schemas", presentationSchema);

        Class<?> spreadsheetSchema = Class.forName(
            "org.openxmlformats.schemas.spreadsheetml.x2006.main.CTWorkbook"
        );
        assertLoadedFromExpectedLib("SpreadsheetML schemas", spreadsheetSchema);

        System.out.println("Apache POI/XMLBeans runtime validation passed.");
    }

    private static String normalizeCurrency(String value) {
        if (value == null) return null;
        String s = value.trim().toUpperCase(Locale.ROOT);
        return CURRENCY.matcher(s).matches() ? s : null;
    }

    private static double parseRate(String s) {
        return Double.parseDouble(s.replace(",", ""));
    }

    private static List<UpdateInfo> extractUpdates(
        int slideIndex,
        String text,
        Rectangle2D anchor
    ) {
        List<UpdateInfo> result = new ArrayList<>();
        if (text == null || text.trim().isEmpty()) return result;

        Set<String> dedup = new HashSet<>();

        Matcher a = RATE_A.matcher(text);
        while (a.find()) {
            String from = a.group(1).toUpperCase(Locale.ROOT);
            String to = a.group(2).toUpperCase(Locale.ROOT);
            double rate = parseRate(a.group(3));
            String key = from + "|" + to + "|" + rate;
            if (dedup.add(key)) {
                result.add(new UpdateInfo(slideIndex, from, to, rate, text, anchor));
            }
        }

        Matcher b = RATE_B.matcher(text);
        while (b.find()) {
            String from = b.group(1).toUpperCase(Locale.ROOT);
            double rate = parseRate(b.group(2));
            String to = b.group(3).toUpperCase(Locale.ROOT);
            String key = from + "|" + to + "|" + rate;
            if (dedup.add(key)) {
                result.add(new UpdateInfo(slideIndex, from, to, rate, text, anchor));
            }
        }

        return result;
    }

    private static String formattedCell(Cell cell, DataFormatter formatter) {
        if (cell == null) return "";
        try {
            return formatter.formatCellValue(cell).trim();
        } catch (RuntimeException ex) {
            return "";
        }
    }

    private static List<MatrixInfo> detectMatrices(Workbook wb) {
        List<MatrixInfo> matrices = new ArrayList<>();
        DataFormatter formatter = new DataFormatter();

        for (int si = 0; si < wb.getNumberOfSheets(); si++) {
            Sheet sheet = wb.getSheetAt(si);
            Map<Integer, Integer> currencyCountByRow = new HashMap<>();
            Map<Integer, Integer> currencyCountByColumn = new HashMap<>();

            for (Row row : sheet) {
                for (Cell cell : row) {
                    String value = normalizeCurrency(formattedCell(cell, formatter));
                    if (value == null) continue;
                    currencyCountByRow.merge(cell.getRowIndex(), 1, Integer::sum);
                    currencyCountByColumn.merge(cell.getColumnIndex(), 1, Integer::sum);
                }
            }

            List<Integer> possibleHeaderRows = new ArrayList<>();
            List<Integer> possibleLabelColumns = new ArrayList<>();

            for (Map.Entry<Integer, Integer> e : currencyCountByRow.entrySet()) {
                if (e.getValue() >= 2) possibleHeaderRows.add(e.getKey());
            }
            for (Map.Entry<Integer, Integer> e : currencyCountByColumn.entrySet()) {
                if (e.getValue() >= 2) possibleLabelColumns.add(e.getKey());
            }

            for (int headerRowIndex : possibleHeaderRows) {
                Row headerRow = sheet.getRow(headerRowIndex);
                if (headerRow == null) continue;

                Map<String, Integer> colMap = new LinkedHashMap<>();
                for (Cell cell : headerRow) {
                    String currency = normalizeCurrency(formattedCell(cell, formatter));
                    if (currency != null) colMap.put(currency, cell.getColumnIndex());
                }

                for (int labelColumn : possibleLabelColumns) {
                    Map<String, Integer> rowMap = new LinkedHashMap<>();
                    for (Row row : sheet) {
                        Cell cell = row.getCell(
                            labelColumn,
                            Row.MissingCellPolicy.RETURN_BLANK_AS_NULL
                        );
                        String currency = normalizeCurrency(formattedCell(cell, formatter));
                        if (currency != null) rowMap.put(currency, row.getRowNum());
                    }

                    Set<String> overlap = new HashSet<>(colMap.keySet());
                    overlap.retainAll(rowMap.keySet());
                    if (overlap.size() < 2) continue;

                    int score = overlap.size() * 100 + Math.min(colMap.size(), rowMap.size());
                    matrices.add(new MatrixInfo(
                        si, headerRowIndex, labelColumn, colMap, rowMap, score
                    ));
                }
            }
        }

        matrices.sort((a, b) -> Integer.compare(b.score, a.score));
        return matrices;
    }

    private static Rectangle2D safeAnchor(XSLFShape shape) {
        try {
            return shape.getAnchor();
        } catch (RuntimeException ex) {
            return null;
        }
    }

    private static void inspectShape(
        XSLFShape shape,
        int slideIndex,
        List<UpdateInfo> updates,
        List<EmbeddedWorkbook> embeddings,
        Set<String> acceptedPartNames
    ) {
        if (shape instanceof XSLFTextShape) {
            XSLFTextShape ts = (XSLFTextShape) shape;
            updates.addAll(extractUpdates(slideIndex, ts.getText(), safeAnchor(shape)));
        }

        if (shape instanceof XSLFObjectShape) {
            XSLFObjectShape os = (XSLFObjectShape) shape;
            try {
                XSLFObjectData data = os.getObjectData();
                if (data == null) {
                    System.err.println(
                        "OLE object on slide " + (slideIndex + 1) + " has no object data."
                    );
                } else {
                    String partName = data.getPackagePart().getPartName().getName();
                    byte[] rawBytes = readAll(os.readObjectDataRaw());
                    byte[] workbookBytes = readAll(os.readObjectData());

                    System.out.println(
                        "Found OLE object on slide " + (slideIndex + 1) +
                        ": " + partName +
                        ", ProgID=" + os.getProgId() +
                        ", raw=" + rawBytes.length + " bytes" +
                        ", unwrapped=" + workbookBytes.length + " bytes" +
                        ", unwrapped signature=" + signature(workbookBytes)
                    );

                    try (Workbook wb = WorkbookFactory.create(
                            new ByteArrayInputStream(workbookBytes))) {

                        if (!(wb instanceof XSSFWorkbook)) {
                            System.err.println("  Skipping: embedded workbook is not OOXML/XLSX.");
                        } else {
                            List<MatrixInfo> matrices = detectMatrices(wb);
                            System.out.println(
                                "  Workbook opened; sheets=" + wb.getNumberOfSheets() +
                                ", detected matrices=" + matrices.size()
                            );

                            if (!matrices.isEmpty()) {
                                embeddings.add(new EmbeddedWorkbook(
                                    slideIndex,
                                    partName,
                                    safeAnchor(shape),
                                    workbookBytes,
                                    matrices,
                                    os,
                                    rawBytes,
                                    null
                                ));
                                acceptedPartNames.add(partName);
                                System.out.println("  Accepted embedded Excel workbook: " + partName);
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.err.println(
                    "Failed to inspect OLE object on slide " + (slideIndex + 1) +
                    ": " + ex.getClass().getName() + ": " + ex.getMessage()
                );
                ex.printStackTrace(System.err);
            }
        }

        if (shape instanceof XSLFGroupShape) {
            XSLFGroupShape group = (XSLFGroupShape) shape;
            for (XSLFShape child : group.getShapes()) {
                inspectShape(child, slideIndex, updates, embeddings, acceptedPartNames);
            }
        }
    }

    private static UnwrappedEmbedding unwrapPackagePart(byte[] raw) throws Exception {
        if (isZipPackage(raw)) {
            return new UnwrappedEmbedding(raw, null);
        }

        if (!isOle2(raw)) {
            return null;
        }

        try (POIFSFileSystem poifs = new POIFSFileSystem(new ByteArrayInputStream(raw))) {
            DirectoryNode root = poifs.getRoot();
            String[] candidates = {"Package", "Contents", "CONTENTS", "CONTENTSV30"};
            for (String entryName : candidates) {
                if (!root.hasEntry(entryName)) continue;
                byte[] payload = readAll(root.createDocumentInputStream(entryName));
                if (payload.length > 0) {
                    return new UnwrappedEmbedding(payload, entryName);
                }
            }
        }

        return null;
    }

    private static void inspectPackageLevelEmbeddings(
        XMLSlideShow ppt,
        List<EmbeddedWorkbook> embeddings,
        Set<String> acceptedPartNames
    ) {
        try {
            for (PackagePart part : ppt.getAllEmbeddedParts()) {
                String partName = part.getPartName().getName();
                if (acceptedPartNames.contains(partName)) continue;

                try {
                    byte[] raw = readAll(part.getInputStream());
                    UnwrappedEmbedding unwrapped = unwrapPackagePart(raw);
                    if (unwrapped == null) continue;

                    byte[] workbookBytes = unwrapped.workbookBytes;
                    try (Workbook wb = WorkbookFactory.create(
                            new ByteArrayInputStream(workbookBytes))) {

                        if (!(wb instanceof XSSFWorkbook)) continue;

                        List<MatrixInfo> matrices = detectMatrices(wb);
                        System.out.println(
                            "Package-level embedding: " + partName +
                            ", raw=" + raw.length + " bytes" +
                            ", payload=" + workbookBytes.length + " bytes" +
                            ", detected matrices=" + matrices.size()
                        );

                        if (!matrices.isEmpty()) {
                            embeddings.add(new EmbeddedWorkbook(
                                -1,
                                partName,
                                null,
                                workbookBytes,
                                matrices,
                                null,
                                raw,
                                unwrapped.oleEntryName
                            ));
                            acceptedPartNames.add(partName);
                            System.out.println(
                                "  Accepted package-level Excel workbook: " + partName
                            );
                        }
                    }
                } catch (Exception ex) {
                    System.err.println(
                        "Skipping package-level embedding " + partName +
                        ": " + ex.getClass().getSimpleName() + ": " + ex.getMessage()
                    );
                }
            }
        } catch (Exception ex) {
            System.err.println(
                "Warning: could not enumerate package-level embeddings: " + ex.getMessage()
            );
        }
    }

    private static double shapeDistance(Rectangle2D a, Rectangle2D b) {
        if (a == null || b == null) return 1.0e9;

        double dx = Math.max(
            Math.max(a.getMinX() - b.getMaxX(), b.getMinX() - a.getMaxX()),
            0.0
        );
        double dy = Math.max(
            Math.max(a.getMinY() - b.getMaxY(), b.getMinY() - a.getMaxY()),
            0.0
        );
        return Math.hypot(dx, dy);
    }

    private static Match chooseMatch(
        List<UpdateInfo> updates,
        List<EmbeddedWorkbook> embeddings
    ) {
        Match best = null;

        for (UpdateInfo update : updates) {
            for (EmbeddedWorkbook embedding : embeddings) {
                boolean sameSlide = embedding.slideIndex < 0
                    || update.slideIndex == embedding.slideIndex;
                if (!sameSlide) continue;

                for (MatrixInfo matrix : embedding.matrices) {
                    if (!matrix.supports(update.from, update.to)) continue;

                    double distancePenalty;
                    if (embedding.slideIndex < 0) {
                        distancePenalty = 1.0e8;
                    } else {
                        distancePenalty = shapeDistance(update.anchor, embedding.anchor);
                    }

                    double score = distancePenalty - matrix.score * 0.0001;
                    if (best == null || score < best.score) {
                        best = new Match(update, embedding, matrix, score);
                    }
                }
            }
        }

        if (best == null) {
            throw new IllegalStateException(
                "Could not associate an exchange-rate update with an embedded Excel matrix."
            );
        }

        return best;
    }

    private static Cell getExistingCell(Sheet sheet, int rowIndex, int columnIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) {
            throw new IllegalStateException("Expected exchange-rate row is missing: " + rowIndex);
        }

        Cell cell = row.getCell(
            columnIndex,
            Row.MissingCellPolicy.RETURN_BLANK_AS_NULL
        );
        if (cell == null) {
            throw new IllegalStateException(
                "Expected exchange-rate cell is missing: row=" + rowIndex +
                ", col=" + columnIndex
            );
        }
        return cell;
    }

    private static Map<String, String> snapshotFormulas(Workbook wb) {
        Map<String, String> result = new TreeMap<>();
        for (int si = 0; si < wb.getNumberOfSheets(); si++) {
            Sheet sheet = wb.getSheetAt(si);
            for (Row row : sheet) {
                for (Cell cell : row) {
                    if (cell.getCellType() == CellType.FORMULA) {
                        String key = si + ":" + cell.getRowIndex() + ":" + cell.getColumnIndex();
                        result.put(key, cell.getCellFormula());
                    }
                }
            }
        }
        return result;
    }

    private static double evaluateNumeric(Cell cell, FormulaEvaluator evaluator) {
        if (cell.getCellType() == CellType.FORMULA) {
            CellValue value = evaluator.evaluate(cell);
            if (value == null || value.getCellType() != CellType.NUMERIC) {
                throw new IllegalStateException("Formula result is not numeric.");
            }
            return value.getNumberValue();
        }
        if (cell.getCellType() == CellType.NUMERIC) {
            return cell.getNumericCellValue();
        }
        if (cell.getCellType() == CellType.STRING) {
            return Double.parseDouble(cell.getStringCellValue().trim());
        }
        throw new IllegalStateException("Exchange-rate cell is not numeric.");
    }

    private static void assertClose(double actual, double expected, String description) {
        double tolerance = Math.max(1.0e-10, Math.abs(expected) * 1.0e-8);
        if (Math.abs(actual - expected) > tolerance) {
            throw new IllegalStateException(
                description + ": expected=" + expected + ", actual=" + actual
            );
        }
    }

    private static byte[] updateWorkbook(Match match) throws Exception {
        UpdateInfo update = match.update;
        MatrixInfo matrix = match.matrix;

        try (Workbook wb = WorkbookFactory.create(
                new ByteArrayInputStream(match.embedding.workbookBytes))) {

            if (!(wb instanceof XSSFWorkbook)) {
                throw new IllegalStateException("Selected workbook is not OOXML/XLSX.");
            }

            Map<String, String> formulasBefore = snapshotFormulas(wb);
            Sheet sheet = wb.getSheetAt(matrix.sheetIndex);

            int directRow = matrix.currencyRows.get(update.from);
            int directCol = matrix.currencyColumns.get(update.to);
            int inverseRow = matrix.currencyRows.get(update.to);
            int inverseCol = matrix.currencyColumns.get(update.from);

            Cell direct = getExistingCell(sheet, directRow, directCol);
            Cell inverse = getExistingCell(sheet, inverseRow, inverseCol);

            boolean directIsFormula = direct.getCellType() == CellType.FORMULA;
            boolean inverseIsFormula = inverse.getCellType() == CellType.FORMULA;

            if (!directIsFormula) {
                direct.setCellValue(update.rate);
                System.out.println(
                    "Updating constant cell " + update.from + " -> " + update.to +
                    " to " + update.rate
                );
            } else if (!inverseIsFormula) {
                double inverseRate = 1.0 / update.rate;
                inverse.setCellValue(inverseRate);
                System.out.println(
                    "Direct rate cell is a formula; updating inverse constant " +
                    update.to + " -> " + update.from + " to " + inverseRate
                );
            } else {
                throw new IllegalStateException(
                    "Both directional rate cells are formulas. " +
                    "No non-formula base rate is available without changing formula semantics."
                );
            }

            FormulaEvaluator evaluator = wb.getCreationHelper().createFormulaEvaluator();
            evaluator.clearAllCachedResultValues();
            try {
                evaluator.evaluateAll();
            } catch (RuntimeException ex) {
                System.err.println(
                    "Warning: full POI formula evaluation encountered an unsupported formula: " +
                    ex.getMessage()
                );
            }

            wb.setForceFormulaRecalculation(true);

            FormulaEvaluator targetEvaluator = wb.getCreationHelper().createFormulaEvaluator();
            double targetValue = evaluateNumeric(direct, targetEvaluator);
            assertClose(targetValue, update.rate, "Updated direct exchange rate");

            Map<String, String> formulasAfterEdit = snapshotFormulas(wb);
            if (!formulasBefore.equals(formulasAfterEdit)) {
                throw new IllegalStateException("Formula structure changed during edit.");
            }

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            byte[] serialized = out.toByteArray();

            if (!isZipPackage(serialized)) {
                throw new IllegalStateException("Serialized workbook is not OOXML/XLSX.");
            }

            try (Workbook check = WorkbookFactory.create(
                    new ByteArrayInputStream(serialized))) {
                Map<String, String> formulasAfterWrite = snapshotFormulas(check);
                if (!formulasBefore.equals(formulasAfterWrite)) {
                    throw new IllegalStateException(
                        "Formula structure changed after XLSX serialization."
                    );
                }

                Sheet checkSheet = check.getSheetAt(matrix.sheetIndex);
                Cell checkDirect = getExistingCell(checkSheet, directRow, directCol);
                FormulaEvaluator checkEvaluator =
                    check.getCreationHelper().createFormulaEvaluator();
                double checkedRate = evaluateNumeric(checkDirect, checkEvaluator);
                assertClose(
                    checkedRate,
                    update.rate,
                    "Serialized workbook exchange rate"
                );
            }

            return serialized;
        }
    }

    private static byte[] replaceOleEntry(
        byte[] originalRaw,
        String entryName,
        byte[] updatedWorkbook
    ) throws Exception {
        if (entryName == null) {
            throw new IllegalStateException("OLE fallback has no workbook entry name.");
        }

        try (POIFSFileSystem poifs = new POIFSFileSystem(
                new ByteArrayInputStream(originalRaw));
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {

            poifs.getRoot().createOrUpdateDocument(
                entryName,
                new ByteArrayInputStream(updatedWorkbook)
            );
            poifs.writeFilesystem(out);
            return out.toByteArray();
        }
    }

    private static byte[] buildRawReplacement(
        Match match,
        byte[] updatedWorkbook
    ) throws Exception {
        EmbeddedWorkbook embedding = match.embedding;

        if (embedding.objectShape != null) {
            try (OutputStream objectOut = embedding.objectShape.updateObjectData(
                    ObjectMetaData.Application.EXCEL_V12,
                    null)) {
                objectOut.write(updatedWorkbook);
            }

            byte[] roundTripWorkbook = readAll(embedding.objectShape.readObjectData());
            if (!isZipPackage(roundTripWorkbook)) {
                throw new IllegalStateException(
                    "POI rewrapped object no longer exposes an XLSX payload."
                );
            }

            try (Workbook check = WorkbookFactory.create(
                    new ByteArrayInputStream(roundTripWorkbook))) {
                if (!(check instanceof XSSFWorkbook)) {
                    throw new IllegalStateException(
                        "POI rewrapped object does not contain an OOXML workbook."
                    );
                }
            }

            return readAll(embedding.objectShape.readObjectDataRaw());
        }

        if (isZipPackage(embedding.originalRawBytes)) {
            return updatedWorkbook;
        }

        if (isOle2(embedding.originalRawBytes)) {
            return replaceOleEntry(
                embedding.originalRawBytes,
                embedding.oleEntryName,
                updatedWorkbook
            );
        }

        throw new IllegalStateException(
            "Selected embedding has an unsupported raw package format."
        );
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 4) {
            throw new IllegalArgumentException(
                "Usage: SolvePptxRates <input.pptx> <updated.xlsx> " +
                "<updated-object.bin> <embedding-name.txt>"
            );
        }

        validatePoiRuntime();

        String inputPptx = args[0];
        String updatedXlsx = args[1];
        String updatedObjectFile = args[2];
        String embeddingNameFile = args[3];

        List<UpdateInfo> updates = new ArrayList<>();
        List<EmbeddedWorkbook> embeddings = new ArrayList<>();
        Set<String> acceptedPartNames = new HashSet<>();

        try (InputStream in = new BufferedInputStream(new FileInputStream(inputPptx));
             XMLSlideShow ppt = new XMLSlideShow(in)) {

            List<XSLFSlide> slides = ppt.getSlides();
            System.out.println("PPTX opened successfully; slides: " + slides.size());

            for (int si = 0; si < slides.size(); si++) {
                XSLFSlide slide = slides.get(si);
                System.out.println(
                    "Inspecting slide " + (si + 1) + "; shapes=" + slide.getShapes().size()
                );

                for (XSLFShape shape : slide.getShapes()) {
                    inspectShape(shape, si, updates, embeddings, acceptedPartNames);
                }
            }

            inspectPackageLevelEmbeddings(ppt, embeddings, acceptedPartNames);

            System.out.println("Candidate rate updates found: " + updates.size());
            System.out.println(
                "Candidate embedded exchange workbooks found: " + embeddings.size()
            );

            if (updates.isEmpty()) {
                throw new IllegalStateException("No updated exchange-rate text was found.");
            }

            if (embeddings.isEmpty()) {
                throw new IllegalStateException(
                    "No embedded OOXML Excel exchange-rate workbook was found. " +
                    "Check the preceding OLE/package diagnostic lines."
                );
            }

            Match match = chooseMatch(updates, embeddings);

            System.out.println("Selected update text: " + match.update.sourceText);
            System.out.println(
                "Selected pair: " + match.update.from + " -> " + match.update.to +
                " = " + match.update.rate
            );
            System.out.println("Selected embedding: " + match.embedding.packagePartName);

            byte[] updatedWorkbook = updateWorkbook(match);
            Files.write(Paths.get(updatedXlsx), updatedWorkbook);

            byte[] updatedRawObject = buildRawReplacement(match, updatedWorkbook);
            if (updatedRawObject.length == 0) {
                throw new IllegalStateException("Updated raw embedding is empty.");
            }

            Files.write(Paths.get(updatedObjectFile), updatedRawObject);

            String packagePart = match.embedding.packagePartName;
            if (packagePart.startsWith("/")) {
                packagePart = packagePart.substring(1);
            }

            Files.write(
                Paths.get(embeddingNameFile),
                packagePart.getBytes(StandardCharsets.UTF_8)
            );

            System.out.println("Updated XLSX written to: " + updatedXlsx);
            System.out.println(
                "Raw replacement object written to: " + updatedObjectFile +
                " (" + updatedRawObject.length + " bytes, signature=" +
                signature(updatedRawObject) + ")"
            );
        }
    }
}
JAVA_SOURCE

echo "[2/5] Compiling Apache POI implementation..."

javac \
    -proc:none \
    -encoding UTF-8 \
    -cp "${JAVA_LIB}/*" \
    -d "${JAVA_CLASSES}" \
    "${JAVA_FILE}"

echo "[3/5] Inspecting PPTX and updating embedded workbook..."

java \
    -Xms128m \
    -Xmx1024m \
    -Dexpected.lib.dir="${JAVA_LIB}" \
    -cp "${JAVA_CLASSES}:${JAVA_LIB}/*" \
    SolvePptxRates \
    "${INPUT_FILE}" \
    "${UPDATED_XLSX}" \
    "${UPDATED_OBJECT}" \
    "${EMBED_NAME_FILE}"

for produced in "${UPDATED_XLSX}" "${UPDATED_OBJECT}" "${EMBED_NAME_FILE}"; do
    if [ ! -s "${produced}" ]; then
        echo "ERROR: Expected output was not produced: ${produced}" >&2
        exit 1
    fi
done

echo "[4/5] Surgically replacing the embedded object..."

python3 <<'PYTHON_REPLACE'
import os
import zipfile

INPUT = "/root/input.pptx"
OUTPUT = "/root/results.pptx"
UPDATED_OBJECT = "/tmp/poi_pptx_rate_solution/updated_embedding_object.bin"
EMBED_NAME_FILE = "/tmp/poi_pptx_rate_solution/embedding_name.txt"

with open(EMBED_NAME_FILE, "r", encoding="utf-8") as f:
    embedding_name = f.read().strip()

if not embedding_name:
    raise RuntimeError("Empty embedding package name")

with open(UPDATED_OBJECT, "rb") as f:
    updated_object = f.read()

if not updated_object:
    raise RuntimeError("Updated embedding object is empty")

is_zip = updated_object.startswith(b"PK\x03\x04")
is_ole2 = updated_object.startswith(bytes.fromhex("D0CF11E0A1B11AE1"))

if not (is_zip or is_ole2):
    raise RuntimeError(
        "Replacement embedding has an unexpected signature: "
        + updated_object[:8].hex(" ")
    )

print("Replacement object format:", "OOXML ZIP" if is_zip else "OLE2 compound object")

if os.path.exists(OUTPUT):
    os.remove(OUTPUT)

with zipfile.ZipFile(INPUT, "r") as zin:
    names = [info.filename for info in zin.infolist()]

    if embedding_name not in names:
        raise RuntimeError(f"Embedding not found in PPTX package: {embedding_name}")

    with zipfile.ZipFile(OUTPUT, "w") as zout:
        replaced = False

        for info in zin.infolist():
            if info.filename == embedding_name:
                data = updated_object
                replaced = True
            else:
                data = zin.read(info.filename)

            zout.writestr(info, data)

        if not replaced:
            raise RuntimeError("Embedded object was not replaced")

print(f"Replaced package part: {embedding_name}")
PYTHON_REPLACE

echo "[5/5] Performing package-level integrity verification..."

python3 <<'PYTHON_VERIFY'
import hashlib
import io
import os
import zipfile

INPUT = "/root/input.pptx"
OUTPUT = "/root/results.pptx"
UPDATED_OBJECT = "/tmp/poi_pptx_rate_solution/updated_embedding_object.bin"
EMBED_NAME_FILE = "/tmp/poi_pptx_rate_solution/embedding_name.txt"

with open(EMBED_NAME_FILE, "r", encoding="utf-8") as f:
    embedding_name = f.read().strip()

with open(UPDATED_OBJECT, "rb") as f:
    expected_embedding = f.read()

def sha256(data):
    return hashlib.sha256(data).hexdigest()

if not os.path.isfile(OUTPUT) or os.path.getsize(OUTPUT) == 0:
    raise RuntimeError("Output PPTX was not created")

with zipfile.ZipFile(INPUT, "r") as original, zipfile.ZipFile(OUTPUT, "r") as result:
    original_names = [x.filename for x in original.infolist()]
    result_names = [x.filename for x in result.infolist()]

    if original_names != result_names:
        raise RuntimeError("PPTX package entry list changed unexpectedly")

    bad_member = result.testzip()
    if bad_member is not None:
        raise RuntimeError(f"Corrupted ZIP member in result: {bad_member}")

    changed_non_embedding = []
    for name in original_names:
        if name == embedding_name:
            continue
        if sha256(original.read(name)) != sha256(result.read(name)):
            changed_non_embedding.append(name)

    if changed_non_embedding:
        raise RuntimeError(
            "Unexpected PPTX parts changed: " + ", ".join(changed_non_embedding)
        )

    before_embedding = original.read(embedding_name)
    after_embedding = result.read(embedding_name)

    if before_embedding == after_embedding:
        raise RuntimeError("Embedded workbook/object was not modified")

    if after_embedding != expected_embedding:
        raise RuntimeError("PPTX embedding does not match the Java-produced replacement bytes")

    is_zip = after_embedding.startswith(b"PK\x03\x04")
    is_ole2 = after_embedding.startswith(bytes.fromhex("D0CF11E0A1B11AE1"))
    if not (is_zip or is_ole2):
        raise RuntimeError("Replacement embedding has an unexpected file signature")

    if is_zip:
        with zipfile.ZipFile(io.BytesIO(after_embedding), "r") as embedded:
            embedded_bad = embedded.testzip()
            if embedded_bad is not None:
                raise RuntimeError(
                    f"Corrupted member in directly embedded XLSX: {embedded_bad}"
                )
            embedded_names = set(embedded.namelist())
            if "[Content_Types].xml" not in embedded_names:
                raise RuntimeError("Directly embedded XLSX has no [Content_Types].xml")
            if "xl/workbook.xml" not in embedded_names:
                raise RuntimeError("Directly embedded XLSX has no xl/workbook.xml")

print("Outer PPTX package validated.")
print("All non-target package entries are content-identical.")
print("Replacement embedding matches the Java-produced bytes.")
PYTHON_VERIFY

echo
echo "Solution complete: ${OUTPUT_FILE}"

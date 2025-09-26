package com.cwp.heartriskapp.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Map;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

/**
 * Bridges Spring to a Python prediction script.
 *
 * Expected classpath resources:
 *   ml/predict_heart_risk.py
 *   ml/artifacts/ct.joblib
 *   ml/artifacts/heart_model.keras
 *   ml/artifacts/train_columns.json
 *
 * Configure Python interpreter with env var ML_PYTHON, e.g.:
 *   export ML_PYTHON=~/venvs/heart-tf/bin/python
 */
@Service
public class PythonPredictor {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    // Initialized once, thread-safe
    private volatile Path workDir;
    private final Object initLock = new Object();

    public String predict(String jsonPayload) throws Exception {
        ensureWorkdir();
        final String python = resolvePython();
        assertDeps(python);

        // Run: python -W ignore predict_heart_risk.py
        ProcessBuilder pb = new ProcessBuilder(python, "-W", "ignore", workDir.resolve("predict_heart_risk.py").toString());

        // Quiet down noisy logs
        Map<String, String> env = pb.environment();
        env.putIfAbsent("PYTHONWARNINGS", "ignore");
        env.putIfAbsent("TF_CPP_MIN_LOG_LEVEL", "3"); // 0=all, 3=errors only

        // Keep stderr separate so JSON stays clean on stdout
        pb.redirectErrorStream(false);
        pb.directory(workDir.toFile());

        Process p = pb.start();

        // Send request JSON to Python stdin
        try (OutputStream os = p.getOutputStream()) {
            os.write(jsonPayload.getBytes(StandardCharsets.UTF_8));
        }

        String stdout = readAll(p.getInputStream());
        String stderr = readAll(p.getErrorStream());

        int code = p.waitFor();
        if (code != 0) {
            throw new RuntimeException("Python exited " + code + " stderr=" + stderr.trim() + " stdout=" + stdout.trim());
        }

        // Extract { ... } in case anything slipped onto stdout
        String json = extractJsonObject(stdout);
        // Validate it’s JSON
        MAPPER.readTree(json);
        return json;
    }

    // ---------- Initialization / resources ----------

    private void ensureWorkdir() throws IOException {
        if (workDir != null) return;
        synchronized (initLock) {
            if (workDir != null) return;

            workDir = Files.createTempDirectory("ml");
            Path artifacts = workDir.resolve("artifacts");
            Files.createDirectories(artifacts);

            copyCP("ml/predict_heart_risk.py", workDir.resolve("predict_heart_risk.py"));
            copyCP("ml/artifacts/ct.joblib", artifacts.resolve("ct.joblib"));
            copyCP("ml/artifacts/heart_model.keras", artifacts.resolve("heart_model.keras"));
            copyCP("ml/artifacts/train_columns.json", artifacts.resolve("train_columns.json"));

            // Fail fast if anything is missing
            for (String f : new String[] { "ct.joblib", "heart_model.keras", "train_columns.json" }) {
                Path fp = artifacts.resolve(f);
                if (!Files.exists(fp)) {
                    throw new IllegalStateException("Missing ML artifact after copy: " + fp);
                }
            }
        }
    }

    private void copyCP(String cpPath, Path dest) throws IOException {
        Resource res = new ClassPathResource(cpPath);
        if (!res.exists()) {
            throw new FileNotFoundException("Classpath resource not found: " + cpPath);
        }
        try (InputStream in = res.getInputStream()) {
            Files.copy(in, dest, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    // ---------- Python selection & sanity checks ----------

    /**
     * Choose the python interpreter:
     * 1) ML_PYTHON env var (recommended)
     * 2) python3.11, python3.10, python3 (first that runs)
     */
    private String resolvePython() {
        String fromEnv = System.getenv("ML_PYTHON");
        if (fromEnv != null && !fromEnv.isBlank()) return fromEnv;

        for (String cand : List.of("python3.11", "python3.10", "python3")) {
            try {
                Process p = new ProcessBuilder(cand, "--version").start();
                if (p.waitFor() == 0) return cand;
            } catch (Exception ignored) {}
        }
        throw new IllegalStateException(
            "No suitable Python found. Set ML_PYTHON to your venv's python (e.g., ~/venvs/heart-tf/bin/python)."
        );
    }

    /**
     * Ensure required Python modules are importable: joblib, pandas, tensorflow.
     * Throws with a helpful message if any are missing.
     */
    private void assertDeps(String python) throws Exception {
        String code =
            "import importlib, json; mods=['joblib','pandas','tensorflow'];" +
            "missing=[m for m in mods if importlib.util.find_spec(m) is None];" +
            "print(json.dumps(missing))";
        Process p = new ProcessBuilder(python, "-c", code).start();
        String out = readAll(p.getInputStream()).trim();
        p.waitFor();

        if (out != null && !out.equals("[]")) {
            throw new IllegalStateException(
                "Missing Python packages: " + out + ". Install them in your interpreter and set ML_PYTHON to that interpreter."
            );
        }
    }

    // ---------- Helpers ----------

    private static String readAll(InputStream is) throws IOException {
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            return sb.toString();
        }
    }

    /**
     * Extracts the outermost JSON object from a string (first '{' to last '}')
     * to guard against incidental logs printed alongside the JSON.
     */
    private static String extractJsonObject(String s) {
        if (s == null) return "";
        String t = s.trim();
        int L = t.indexOf('{');
        int R = t.lastIndexOf('}');
        if (L >= 0 && R >= L) return t.substring(L, R + 1);
        // As a fallback, return trimmed string (ObjectMapper.validate will fail loudly if not JSON)
        return t;
    }
}

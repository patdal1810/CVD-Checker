package com.cwp.heartriskapp.config;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class MlEnvCheck implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(MlEnvCheck.class);

    @Override
    public void run(ApplicationArguments args) throws Exception {
        String py = System.getenv("ML_PYTHON");
        String cmd = System.getenv("ML_PY_CMD");
        log.info("ML_PYTHON='{}' ML_PY_CMD='{}'", py, cmd);

        if (py == null || py.isBlank()) {
            log.warn("ML_PYTHON is not set");
            return;
        }
        // Try importing required libs using that interpreter
        Process p = new ProcessBuilder(py, "-c", "import pandas,joblib,sklearn,tensorflow; print('ML imports OK')")
            .redirectErrorStream(true)
            .start();
        String out;
        try (BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
            out = br.lines().collect(Collectors.joining("\n"));
        }
        int code = p.waitFor();
        log.info("ML import check exit={} output=\n{}", code, out);
    }
}

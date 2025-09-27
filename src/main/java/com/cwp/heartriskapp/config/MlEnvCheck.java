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
    public void run(ApplicationArguments args) {
        try {
            String py = System.getenv("ML_PYTHON");
            log.info("ML_PYTHON='{}'", py);
            if (py == null || py.isBlank()) {
                log.warn("ML_PYTHON not set");
                return;
            }
            Process p = new ProcessBuilder(py, "-c", "import pandas,joblib,sklearn,tensorflow; print('ML imports OK')")
                .redirectErrorStream(true)
                .start();
            String out = new BufferedReader(new InputStreamReader(p.getInputStream())).lines().collect(Collectors.joining("\n"));
            int code = p.waitFor();
            log.info("ML import check exit={} output=\n{}", code, out);
        } catch (Exception e) {
            log.error("ML import check failed (will continue to start): {}", e.toString());
        }
    }
}

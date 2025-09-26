package com.cwp.heartriskapp.web.rest;

import com.cwp.heartriskapp.service.PythonPredictor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class PredictionResource {

    private final PythonPredictor predictor;

    public PredictionResource(PythonPredictor predictor) {
        this.predictor = predictor;
    }

    @PostMapping(value = "/predict", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public String predict(@RequestBody String payload) throws Exception {
        return predictor.predict(payload);
    }
}

package com.example.provider;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Ordinary provider unit/integration test, independent of contract generation.
 */
@WebMvcTest(GreetingController.class)
class GreetingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void returnsGreetingMessage() throws Exception {
        mockMvc.perform(post("/api/greetings")
                        .contentType(APPLICATION_JSON)
                        .content("{\"fullName\":\"Team\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Hello Team"));
    }
}

package com.example.provider;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GreetingController {

    @PostMapping("/api/greetings")
    public GreetingResponse greeting(@RequestBody GreetingRequest request) {
        return new GreetingResponse("Hello " + request.name());
    }
}

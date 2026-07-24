package com.example.provider;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GreetingController {

    @GetMapping("/api/greetings/{name}")
    public Greeting greeting(@PathVariable String name) {
        return new Greeting("Hello " + name);
    }
}

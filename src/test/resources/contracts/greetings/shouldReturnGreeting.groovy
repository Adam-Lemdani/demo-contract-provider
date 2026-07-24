package contracts.greetings

import org.springframework.cloud.contract.spec.Contract

/**
 * Contract for GET /api/greetings/{name}.
 *
 * This single Groovy DSL file drives BOTH sides of the demo:
 *   - Producer: generates a JUnit5 test asserting the controller honours it.
 *   - Consumer: is packaged into the *-stubs.jar and replayed by Stub Runner.
 *
 * The `message` field is the contract-critical assertion.
 */
Contract.make {
    description "should return a greeting for the given name"
    request {
        method GET()
        url "/api/greetings/Adam"
    }
    response {
        status OK()
        headers {
            contentType(applicationJson())
        }
        body(
                message: "Hello Adam"
        )
    }
}

package contracts.greetings

import org.springframework.cloud.contract.spec.Contract

Contract.make {
    description "should return a greeting for the provided JSON payload"
    request {
        method POST()
        urlPath "/api/greetings"
        headers {
            contentType(applicationJson())
        }
        body(
                fullName: "Team"
        )
    }
    response {
        status OK()
        headers {
            contentType(applicationJson())
        }
        body(
                message: "Hello Team"
        )
    }
}

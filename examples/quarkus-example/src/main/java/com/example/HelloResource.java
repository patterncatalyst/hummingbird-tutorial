package com.example;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.Map;

/**
 * Trivial REST resource. Returns a JSON heartbeat including the JVM
 * version so it's easy to confirm the build picked up the runtime
 * image's Java version (and not the builder image's).
 */
@Path("/")
public class HelloResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> heartbeat() {
        return Map.of(
                "status", "ok",
                "runtime", "hummingbird-quarkus",
                "javaVersion", System.getProperty("java.version"),
                "javaVendor", System.getProperty("java.vendor")
        );
    }
}

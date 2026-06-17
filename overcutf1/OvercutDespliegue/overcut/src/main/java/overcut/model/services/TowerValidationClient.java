package overcut.model.services;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@Service
public class TowerValidationClient {

    private final ObjectMapper mapper = new ObjectMapper();

    // ✅ FIX: fuerza HTTP/1.1 para evitar "Invalid HTTP request received." en Uvicorn/Gunicorn
    private final HttpClient client = HttpClient.newBuilder()
            .version(HttpClient.Version.HTTP_1_1)
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    public boolean validate(String themeType,
                            JsonNode themeKeyNode,
                            Long driverId,
                            String lang) {

        try {
            ObjectNode node = mapper.createObjectNode();
            node.put("themeType", themeType);
            node.set("themeKey", themeKeyNode);
            node.put("driverId", driverId);
            node.put("driverName", "");
            node.put("lang", lang);

            String payload = node.toString();

            // (lo dejabas tú) ✅ útil para debug
            System.out.println("Tower validate payload => " + payload);

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(fastapiBaseUrl + "/validate-tower"))
                    .timeout(Duration.ofSeconds(8))
                    .header("Content-Type", "application/json; charset=utf-8")
                    .header("Accept", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                    .build();

            HttpResponse<String> res = client.send(
                    req,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8)
            );

            if (res.statusCode() != 200) {
                throw new RuntimeException("FastAPI error: " + res.body());
            }

            JsonNode root = mapper.readTree(res.body());
            return root.has("valid") && root.get("valid").asBoolean(false);

        } catch (Exception e) {
            throw new RuntimeException("Error calling FastAPI validate-tower", e);
        }
    }
}

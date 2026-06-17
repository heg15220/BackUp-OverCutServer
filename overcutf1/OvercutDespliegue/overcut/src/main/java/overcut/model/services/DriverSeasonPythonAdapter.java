package overcut.model.services;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class DriverSeasonPythonAdapter {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${fastapi.base-url:http://fastapi:8000}")
    private String fastapiBaseUrl;

    private String resolveBaseUrl() {
        // Prioridad: ENV (si existe) -> application.yml/properties (@Value)
        String env = System.getenv("PY_GAMES_URL");
        String base = (env != null && !env.isBlank()) ? env : fastapiBaseUrl;

        if (base == null || base.isBlank()) {
            // fallback ultra seguro
            base = "http://fastapi:8000";
        }

        // Asegura que sea absoluta
        if (!base.startsWith("http://") && !base.startsWith("https://")) {
            base = "http://" + base;
        }

        // Sin barra final
        if (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }

        return base;
    }

    public DriverSeasonGeneratedData generate(String lang) {
        String base = resolveBaseUrl();
        String url = base + "/generate-driver-season-game?lang=" + lang;
        return restTemplate.getForObject(url, DriverSeasonGeneratedData.class);
    }
}

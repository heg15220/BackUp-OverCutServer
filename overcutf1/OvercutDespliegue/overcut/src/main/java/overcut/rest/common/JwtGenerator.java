package overcut.rest.common;

/**
 * The Interface JwtGenerator.
 */
public interface JwtGenerator {
    /**
     * Generate.
     *
     * @param info the info
     * @return the string
     */
    String generate(JwtInfo info);

 // 🆕 nueva sobrecarga con expiración personalizada (en minutos)
    String generate(JwtInfo info, long expirationMinutes);

    /**
     * Gets the info.
     *
     * @param token the token
     * @return the info
     */
    JwtInfo getInfo(String token);
}

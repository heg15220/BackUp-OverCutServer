package overcut.rest.controllers;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import overcut.model.common.exceptions.InstanceNotFoundException;
import overcut.model.entities.CookieConsent;
import overcut.model.services.CookieConsentService;
import overcut.rest.common.CookieUtil;
import overcut.rest.dtos.CookieConsentDto;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@CrossOrigin(
        origins = {
                "https://overcutf1.com",
                "https://www.overcutf1.com",
                "https://www.overcutf1.com/api/users/signUp",
                "http://localhost:3000"
        },
        allowCredentials = "true"
)
@RestController
@RequestMapping("/api/consent")
public class CookieConsentController {

    private static final String CONSENT_COOKIE = "oc_consent";
    private static final String CONSENT_ID_COOKIE = "oc_cid";
    private static final int CONSENT_MAX_AGE_SECONDS = 60 * 60 * 24 * 30 * 6;

    private static final String COOKIE_DOMAIN = ".overcutf1.com";
    private static final String COOKIE_SAMESITE = "None";
    private static final boolean COOKIE_SECURE = true;

    @Autowired
    private CookieConsentService consentService;

    @GetMapping
    public CookieConsentDto getConsent(HttpServletRequest req,
                                       HttpServletResponse resp,
                                       @RequestAttribute(required = false) Long userId)
            throws InstanceNotFoundException {

        String consentId = readCookie(req, CONSENT_ID_COOKIE);
        CookieConsent c = null;

        if (userId != null) {
            c = consentService.findByUserId(userId).orElse(null);

            if (c == null && consentId != null && !consentId.isBlank()) {
                CookieConsent anonymousConsent = consentService.findByConsentId(consentId).orElse(null);
                if (anonymousConsent != null && !consentService.isExpired(anonymousConsent, CONSENT_MAX_AGE_SECONDS)) {
                    consentService.attachAnonymousConsentToUser(consentId, userId);
                    c = consentService.findByUserId(userId).orElse(anonymousConsent);
                }
            }
        } else if (consentId != null && !consentId.isBlank()) {
            c = consentService.findByConsentId(consentId).orElse(null);
        }

        boolean decided = c != null && !consentService.isExpired(c, CONSENT_MAX_AGE_SECONDS);

        CookieConsentDto dto = new CookieConsentDto();
        dto.setDecided(decided);

        if (decided) {
            c = consentService.ensureConsentId(c, consentId);
            refreshConsentCookies(resp, c);

            dto.setPreferences(c.isPreferences());
            dto.setAnalytics(c.isAnalytics());
            dto.setAds(c.isAds());
            dto.setCountry(c.getCountry());
            dto.setDnt(c.getDnt());
        } else {
            if (c != null) {
                expireConsentCookies(resp);
            }

            dto.setPreferences(false);
            dto.setAnalytics(false);
            dto.setAds(false);
            dto.setDnt(false);
        }

        return dto;
    }

    @PutMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void saveConsent(@RequestBody CookieConsentDto dto,
                            HttpServletRequest req,
                            HttpServletResponse resp,
                            @RequestAttribute(required = false) Long userId) throws InstanceNotFoundException {

        String consentId = readCookie(req, CONSENT_ID_COOKIE);

        CookieConsent c;
        if (userId != null) {
            c = consentService.getForUserConsentSave(userId, consentId);
        } else {
            consentId = consentService.ensureConsentIdValue(consentId);
            c = consentService.getByConsentId(consentId);
        }

        c = consentService.saveFlags(c, dto.getPreferences(), dto.getAnalytics(), dto.getAds(),
                dto.getCountry(), dto.getDnt(), dto.getTcfString());
        c = consentService.ensureConsentId(c, consentId);

        refreshConsentCookies(resp, c);
    }

    private void refreshConsentCookies(HttpServletResponse resp, CookieConsent c) {
        String compact = "P" + (c.isPreferences() ? "1" : "0")
                + "|A" + (c.isAnalytics() ? "1" : "0")
                + "|ADS" + (c.isAds() ? "1" : "0");

        CookieUtil.addCookie(resp, CONSENT_COOKIE, compact, CONSENT_MAX_AGE_SECONDS,
                false, COOKIE_SECURE, COOKIE_SAMESITE, COOKIE_DOMAIN, "/");

        CookieUtil.addCookie(resp, CONSENT_ID_COOKIE, c.getConsentId(), CONSENT_MAX_AGE_SECONDS,
                true, COOKIE_SECURE, COOKIE_SAMESITE, COOKIE_DOMAIN, "/");
    }

    private void expireConsentCookies(HttpServletResponse resp) {
        CookieUtil.addCookie(resp, CONSENT_COOKIE, "", 0,
                false, COOKIE_SECURE, COOKIE_SAMESITE, COOKIE_DOMAIN, "/");

        CookieUtil.addCookie(resp, CONSENT_ID_COOKIE, "", 0,
                true, COOKIE_SECURE, COOKIE_SAMESITE, COOKIE_DOMAIN, "/");
    }

    private String readCookie(HttpServletRequest req, String name) {
        if (req.getCookies() == null) return null;
        for (var c : req.getCookies()) {
            if (name.equals(c.getName())) return c.getValue();
        }
        return null;
    }
}

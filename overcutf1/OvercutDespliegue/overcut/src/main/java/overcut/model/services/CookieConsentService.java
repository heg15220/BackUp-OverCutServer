package overcut.model.services;

import org.springframework.dao.DataIntegrityViolationException;
import overcut.model.common.exceptions.InstanceNotFoundException;
import overcut.model.entities.CookieConsent;
import overcut.model.entities.CookieConsentDao;
import overcut.model.entities.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@Transactional
public class CookieConsentService {

    @Autowired
    private CookieConsentDao consentDao;

    @Autowired
    private PermissionChecker permissionChecker;

    public CookieConsent getByUserId(Long userId) throws InstanceNotFoundException {
        User u = permissionChecker.checkUser(userId);
        return consentDao.findByUser(u).orElseGet(() -> {
            CookieConsent c = new CookieConsent();
            c.setUser(u);
            c.setPreferences(false);
            c.setAnalytics(false);
            c.setAds(false);
            c.setDnt(false);
            return consentDao.save(c);
        });
    }

    public CookieConsent getByConsentId(String consentId) {
        return consentDao.findByConsentId(consentId).orElseGet(() -> {
            CookieConsent c = new CookieConsent();
            c.setConsentId(consentId);
            c.setPreferences(false);
            c.setAnalytics(false);
            c.setAds(false);
            c.setDnt(false);
            return consentDao.save(c);
        });
    }

    public CookieConsent getForUserConsentSave(Long userId, String preferredConsentId) throws InstanceNotFoundException {
        User u = permissionChecker.checkUser(userId);
        Optional<CookieConsent> userConsent = consentDao.findByUser(u);

        if (userConsent.isPresent()) {
            return ensureConsentId(userConsent.get(), preferredConsentId);
        }

        if (preferredConsentId != null && !preferredConsentId.isBlank()) {
            Optional<CookieConsent> anonymousConsent = consentDao.findByConsentId(preferredConsentId);
            if (anonymousConsent.isPresent()) {
                CookieConsent c = anonymousConsent.get();
                if (c.getUser() == null || c.getUser().getId().equals(userId)) {
                    c.setUser(u);
                    c.setUpdatedAt(LocalDateTime.now());
                    return consentDao.save(c);
                }
            }
        }

        CookieConsent c = new CookieConsent();
        c.setUser(u);
        c.setPreferences(false);
        c.setAnalytics(false);
        c.setAds(false);
        c.setDnt(false);
        c.setConsentId(nextAvailableConsentId(preferredConsentId));
        return consentDao.save(c);
    }

    public CookieConsent saveFlags(CookieConsent c, Boolean pref, Boolean ana, Boolean ads,
                                   String country, Boolean dnt, String tcf) {
        if (pref != null) c.setPreferences(pref);
        if (ana != null) c.setAnalytics(ana);
        if (ads != null) c.setAds(ads);
        if (country != null) c.setCountry(country);
        c.setDnt(dnt != null ? dnt : false);
        if (tcf != null) c.setTcfString(tcf);

        // This timestamp represents the latest explicit cookie decision.
        // Force it even when the chosen flags are identical to current values
        // (for example rejecting all: false/false/false), otherwise JPA may not
        // dirty-check the entity and expired consent remains expired forever.
        c.setUpdatedAt(LocalDateTime.now());

        return consentDao.save(c);
    }

    public boolean isExpired(CookieConsent c, int maxAgeSeconds) {
        if (c == null) return true;

        LocalDateTime reference = c.getUpdatedAt() != null ? c.getUpdatedAt() : c.getCreatedAt();
        if (reference == null) return true;

        return reference.plusSeconds(maxAgeSeconds).isBefore(LocalDateTime.now());
    }

    public void attachAnonymousConsentToUser(String consentId, Long userId) throws InstanceNotFoundException {
        if (consentId == null || consentId.isBlank()) return;

        User u = permissionChecker.checkUser(userId);
        Optional<CookieConsent> anonymousConsent = consentDao.findByConsentId(consentId);
        if (anonymousConsent.isEmpty()) return;

        CookieConsent anonymous = anonymousConsent.get();
        if (anonymous.getUser() != null && anonymous.getUser().getId().equals(userId)) return;
        if (anonymous.getUser() != null) return;

        Optional<CookieConsent> userConsent = consentDao.findByUser(u);
        if (userConsent.isPresent()) {
            return;
        }

        anonymous.setUser(u);
        anonymous.setUpdatedAt(LocalDateTime.now());
        consentDao.save(anonymous);
    }

    public String ensureConsentIdValue(String consentId) {
        return (consentId == null || consentId.isBlank()) ? nextAvailableConsentId(null) : consentId;
    }

    /**
     * Backwards-compatible name used by other controllers/services.
     */
    public String ensureConsentId(String consentId) {
        return ensureConsentIdValue(consentId);
    }

    public CookieConsent ensureConsentId(CookieConsent c, String preferredConsentId) {
        if (c.getConsentId() != null && !c.getConsentId().isBlank()) {
            return c;
        }

        c.setConsentId(nextAvailableConsentId(preferredConsentId));
        c.setUpdatedAt(LocalDateTime.now());
        return consentDao.save(c);
    }

    private String nextAvailableConsentId(String preferredConsentId) {
        if (preferredConsentId != null && !preferredConsentId.isBlank()
                && consentDao.findByConsentId(preferredConsentId).isEmpty()) {
            return preferredConsentId;
        }

        String next;
        do {
            next = UUID.randomUUID().toString();
        } while (consentDao.findByConsentId(next).isPresent());

        return next;
    }

    public Optional<CookieConsent> findByUserId(Long userId) throws InstanceNotFoundException {
        User u = permissionChecker.checkUser(userId);
        return consentDao.findByUser(u);
    }

    public Optional<CookieConsent> findByConsentId(String consentId) {
        return consentDao.findByConsentId(consentId);
    }

    public CookieConsent upsertByConsentId(String consentId) {
        return consentDao.findByConsentId(consentId).orElseGet(() -> {
            try {
                CookieConsent c = new CookieConsent();
                c.setConsentId(consentId);
                c.setPreferences(false);
                c.setAnalytics(false);
                c.setAds(false);
                c.setDnt(false);
                return consentDao.save(c);
            } catch (DataIntegrityViolationException e) {
                return consentDao.findByConsentId(consentId).orElseThrow();
            }
        });
    }

    public CookieConsent upsertByUserId(Long userId) throws InstanceNotFoundException {
        User u = permissionChecker.checkUser(userId);
        return consentDao.findByUser(u).orElseGet(() -> {
            try {
                CookieConsent c = new CookieConsent();
                c.setUser(u);
                c.setPreferences(false);
                c.setAnalytics(false);
                c.setAds(false);
                c.setDnt(false);
                c.setConsentId(nextAvailableConsentId(null));
                return consentDao.save(c);
            } catch (DataIntegrityViolationException e) {
                return consentDao.findByUser(u).orElseThrow();
            }
        });
    }
}

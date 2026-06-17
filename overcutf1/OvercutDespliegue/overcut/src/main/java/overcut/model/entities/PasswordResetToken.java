package overcut.model.entities;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
public class PasswordResetToken {

    private Long id;
    private String token;
    private LocalDateTime expiration;
    private boolean used = false;
    private User user;

    public PasswordResetToken() {}

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    @Column(nullable = false, unique = true)
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    @Column(nullable = false)
    public LocalDateTime getExpiration() { return expiration; }
    public void setExpiration(LocalDateTime expiration) { this.expiration = expiration; }

    @Column(nullable = false)
    public boolean isUsed() { return used; }
    public void setUsed(boolean used) { this.used = used; }

    @ManyToOne(optional = false)
    @JoinColumn(name = "userId")
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
}

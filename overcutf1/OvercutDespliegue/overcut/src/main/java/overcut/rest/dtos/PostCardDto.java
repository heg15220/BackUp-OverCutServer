package overcut.rest.dtos;

import java.time.LocalDateTime;

public class PostCardDto {

    private Long id;
    private String title;
    private String subtitle;
    private LocalDateTime creationDate;

    private Long categoryId;
    private String categoryName;

    private String language;

    private Long userId;
    private String userName;

    public PostCardDto() {}

    public PostCardDto(Long id, String title, String subtitle, LocalDateTime creationDate,
                       Long categoryId, String categoryName, String language,
                       Long userId, String userName) {
        this.id = id;
        this.title = title;
        this.subtitle = subtitle;
        this.creationDate = creationDate;
        this.categoryId = categoryId;
        this.categoryName = categoryName;
        this.language = language;
        this.userId = userId;
        this.userName = userName;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getSubtitle() { return subtitle; }
    public void setSubtitle(String subtitle) { this.subtitle = subtitle; }

    public LocalDateTime getCreationDate() { return creationDate; }
    public void setCreationDate(LocalDateTime creationDate) { this.creationDate = creationDate; }

    public Long getCategoryId() { return categoryId; }
    public void setCategoryId(Long categoryId) { this.categoryId = categoryId; }

    public String getCategoryName() { return categoryName; }
    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
}

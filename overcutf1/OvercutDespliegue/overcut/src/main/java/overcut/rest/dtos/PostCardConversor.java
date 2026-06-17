package overcut.rest.dtos;

import overcut.model.entities.Post;

import java.util.List;
import java.util.stream.Collectors;

public class PostCardConversor {

    private PostCardConversor() {}

    public static PostCardDto toCard(Post p) {
        return new PostCardDto(
                p.getId(),
                p.getTitle(),
                p.getSubtitle(),
                p.getCreationDate(),
                p.getCategory().getId(),
                p.getCategory().getName(),
                p.getLanguage(),
                p.getUser().getId(),
                p.getUser().getUserName()
        );
    }

    public static List<PostCardDto> toCards(List<Post> posts) {
        return posts.stream().map(PostCardConversor::toCard).collect(Collectors.toList());
    }
}

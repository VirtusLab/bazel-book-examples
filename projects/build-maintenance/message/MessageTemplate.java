package message;

public final class MessageTemplate {
    private MessageTemplate() {}

    public static String render() {
        return GeneratedMessage.details();
    }
}

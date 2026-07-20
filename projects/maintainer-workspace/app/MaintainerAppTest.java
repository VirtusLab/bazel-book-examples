package app;

public final class MaintainerAppTest {
    public static void main(String[] args) {
        String rendered = MaintainerApp.render("test");

        assertContains(rendered, "launcher=java");
        assertContains(rendered, "mode=test");
        assertContains(rendered, "platform=" + PlatformProfile.name());
        assertContains(rendered, "message=" + PlatformProfile.message());
    }

    private static void assertContains(String text, String expected) {
        if (!text.contains(expected)) {
            throw new AssertionError("expected output to contain '" + expected + "' but got:\n" + text);
        }
    }
}

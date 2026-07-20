package app;

public final class PlatformProfile {
    private PlatformProfile() {}

    public static String name() {
        return "macos";
    }

    public static String message() {
        return "macos target selected";
    }
}

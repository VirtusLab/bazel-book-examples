package app;

public final class PlatformProfile {
    private PlatformProfile() {}

    public static String name() {
        return "linux";
    }

    public static String message() {
        return "linux target selected";
    }
}

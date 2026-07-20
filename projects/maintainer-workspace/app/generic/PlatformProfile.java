package app;

public final class PlatformProfile {
    private PlatformProfile() {}

    public static String name() {
        return "generic";
    }

    public static String message() {
        return "host/default target selected";
    }
}

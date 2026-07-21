package com.plansphere.utils;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.Properties;

public class ConfigReader {
    private static Properties properties;

    static {
        try {
            properties = new Properties();
            // Try loading from config directory
            String configPath = Paths.get("config", "config.properties").toAbsolutePath().toString();
            try (FileInputStream input = new FileInputStream(configPath)) {
                properties.load(input);
            } catch (IOException e) {
                // Try classpath fallback
                properties.load(ConfigReader.class.getClassLoader().getResourceAsStream("config.properties"));
            }
        } catch (Exception e) {
            System.err.println("Could not load config.properties: " + e.getMessage());
        }
    }

    public static String getProperty(String key) {
        return properties.getProperty(key);
    }

    public static String getProperty(String key, String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }

    public static int getIntProperty(String key, int defaultValue) {
        String val = properties.getProperty(key);
        if (val == null) return defaultValue;
        try {
            return Integer.parseInt(val.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }
}

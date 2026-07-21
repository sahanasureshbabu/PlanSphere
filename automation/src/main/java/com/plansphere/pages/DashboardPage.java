package com.plansphere.pages;

import io.appium.java_client.AppiumDriver;
import io.appium.java_client.pagefactory.AndroidFindBy;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;

public class DashboardPage extends BasePage {

    @AndroidFindBy(accessibility = "tab-home")
    private WebElement homeTab;

    @AndroidFindBy(accessibility = "tab-bills")
    private WebElement billsTab;

    @AndroidFindBy(accessibility = "tab-vault")
    private WebElement vaultTab;

    @AndroidFindBy(accessibility = "tab-analytics")
    private WebElement analyticsTab;

    @AndroidFindBy(accessibility = "tab-settings")
    private WebElement settingsTab;

    @AndroidFindBy(accessibility = "stat-total-bills")
    private WebElement totalBillsStat;

    @AndroidFindBy(accessibility = "stat-total-docs")
    private WebElement totalDocsStat;

    @AndroidFindBy(accessibility = "notifications-button")
    private WebElement notificationsBtn;

    public DashboardPage(AppiumDriver driver) {
        super(driver);
    }

    public void navigateToHome() {
        try { click(homeTab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'Home') or contains(@text, 'Home')]")); }
    }

    public void navigateToBills() {
        try { click(billsTab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'Bills') or contains(@text, 'Bills')]")); }
    }

    public void navigateToVault() {
        try { click(vaultTab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'Vault') or contains(@text, 'Vault') or contains(@content-desc, 'Documents') or contains(@text, 'Documents')]")); }
    }

    public void navigateToAnalytics() {
        try { click(analyticsTab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'Analytics') or contains(@text, 'Analytics')]")); }
    }

    public void navigateToSettings() {
        try { click(settingsTab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'Settings') or contains(@text, 'Settings')]")); }
    }

    public void clickNotifications() {
        try { click(notificationsBtn); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'notifications') or contains(@content-desc, 'Notifications')]")); }
    }

    public int getTotalBillsCount() {
        try {
            return Integer.parseInt(getText(totalBillsStat).trim());
        } catch (Exception e) {
            try {
                String text = getText(By.xpath("//*[contains(@content-desc, 'bills') or contains(@text, 'bills')]/preceding-sibling::* | //*[contains(@content-desc, 'Total Bills') or contains(@text, 'Total Bills')]"));
                return Integer.parseInt(text.replaceAll("[^0-9]", "").trim());
            } catch (Exception ex) {
                return 0;
            }
        }
    }

    public int getTotalDocsCount() {
        try {
            return Integer.parseInt(getText(totalDocsStat).trim());
        } catch (Exception e) {
            try {
                String text = getText(By.xpath("//*[contains(@content-desc, 'documents') or contains(@text, 'documents')]/preceding-sibling::* | //*[contains(@content-desc, 'Total Documents') or contains(@text, 'Total Documents')]"));
                return Integer.parseInt(text.replaceAll("[^0-9]", "").trim());
            } catch (Exception ex) {
                return 0;
            }
        }
    }
}

package com.plansphere.pages;

import io.appium.java_client.AppiumDriver;
import io.appium.java_client.pagefactory.AndroidFindBy;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;

public class LoginPage extends BasePage {

    // Locators using PageFactory
    @AndroidFindBy(accessibility = "email-input")
    private WebElement emailField;

    @AndroidFindBy(accessibility = "password-input")
    private WebElement passwordField;

    @AndroidFindBy(accessibility = "login-button")
    private WebElement loginButton;

    @AndroidFindBy(accessibility = "register-link")
    private WebElement registerLink;

    @AndroidFindBy(accessibility = "forgot-link")
    private WebElement forgotLink;

    // Direct Locators for dynamic checks
    private final By emailErrorLocator = By.xpath("//*[contains(@content-desc, 'Please enter a valid email') or contains(@text, 'Please enter a valid email')]");
    private final By passwordErrorLocator = By.xpath("//*[contains(@content-desc, 'Password') or contains(@text, 'Password')]");
    private final By toastMessageLocator = By.xpath("//android.widget.Toast | //*[contains(@text, 'success') or contains(@content-desc, 'success') or contains(@text, 'Invalid') or contains(@content-desc, 'Invalid')]");

    public LoginPage(AppiumDriver driver) {
        super(driver);
    }

    public void enterEmail(String email) {
        try {
            type(emailField, email);
        } catch (Exception e) {
            // Fallback locator
            type(By.xpath("//android.widget.EditText[1]"), email);
        }
    }

    public void enterPassword(String password) {
        try {
            type(passwordField, password);
        } catch (Exception e) {
            // Fallback locator
            type(By.xpath("//android.widget.EditText[2]"), password);
        }
    }

    public void clickLogin() {
        try {
            click(loginButton);
        } catch (Exception e) {
            // Fallback locator
            click(By.xpath("//android.widget.Button | //*[contains(@content-desc, 'Sign In') or contains(@text, 'Sign In')]"));
        }
    }

    public void login(String email, String password) {
        enterEmail(email);
        enterPassword(password);
        clickLogin();
    }

    public void clickRegisterLink() {
        try {
            click(registerLink);
        } catch (Exception e) {
            click(By.xpath("//*[contains(@content-desc, 'Register') or contains(@text, 'Register') or contains(@content-desc, 'Sign Up') or contains(@text, 'Sign Up')]"));
        }
    }

    public void clickForgotPasswordLink() {
        try {
            click(forgotLink);
        } catch (Exception e) {
            click(By.xpath("//*[contains(@content-desc, 'Forgot') or contains(@text, 'Forgot')]"));
        }
    }

    public boolean isEmailErrorVisible() {
        return isElementDisplayed(emailErrorLocator);
    }

    public String getToastMessage() {
        try {
            return getText(toastMessageLocator);
        } catch (Exception e) {
            return "";
        }
    }
}

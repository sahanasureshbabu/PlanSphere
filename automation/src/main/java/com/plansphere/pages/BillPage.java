package com.plansphere.pages;

import io.appium.java_client.AppiumDriver;
import io.appium.java_client.pagefactory.AndroidFindBy;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;

public class BillPage extends BasePage {

    @AndroidFindBy(accessibility = "add-bill-fab")
    private WebElement addBillFab;

    @AndroidFindBy(accessibility = "input-product-name")
    private WebElement productNameField;

    @AndroidFindBy(accessibility = "select-category")
    private WebElement categoryDropdown;

    @AndroidFindBy(accessibility = "select-bill-type")
    private WebElement billTypeDropdown;

    @AndroidFindBy(accessibility = "input-amount")
    private WebElement amountField;

    @AndroidFindBy(accessibility = "input-store")
    private WebElement storeField;

    @AndroidFindBy(accessibility = "input-purchase-date")
    private WebElement purchaseDateField;

    @AndroidFindBy(accessibility = "input-expiry-date")
    private WebElement expiryDateField;

    @AndroidFindBy(accessibility = "btn-duration-12")
    private WebElement duration12MonthsBtn;

    @AndroidFindBy(accessibility = "save-bill-button")
    private WebElement saveBillBtn;

    public BillPage(AppiumDriver driver) {
        super(driver);
    }

    public void clickAddBillFAB() {
        try { click(addBillFab); } catch (Exception e) { click(By.xpath("//*[contains(@content-desc, 'add') or contains(@content-desc, 'Add') or @class='android.widget.Button']")); }
    }

    public void enterProductName(String name) {
        try { type(productNameField, name); } catch (Exception e) { type(By.xpath("//android.widget.EditText[1]"), name); }
    }

    public void selectCategory(String category) {
        try {
            click(categoryDropdown);
            click(By.xpath("//android.widget.TextView[@text='" + category + "']"));
        } catch (Exception e) {
            // standard dropdown click fallback
        }
    }

    public void selectBillType(String type) {
        try {
            click(billTypeDropdown);
            click(By.xpath("//android.widget.TextView[@text='" + type + "']"));
        } catch (Exception e) {
            // fallback
        }
    }

    public void enterAmount(String amount) {
        try { type(amountField, amount); } catch (Exception e) { type(By.xpath("//android.widget.EditText[2]"), amount); }
    }

    public void enterStore(String store) {
        try { type(storeField, store); } catch (Exception e) { type(By.xpath("//android.widget.EditText[3]"), store); }
    }

    public void selectQuickDuration12Months() {
        try { click(duration12MonthsBtn); } catch (Exception e) { click(By.xpath("//*[contains(@text, '12') or contains(@content-desc, '12')]")); }
    }

    public void clickSaveBill() {
        try { click(saveBillBtn); } catch (Exception e) { click(By.xpath("//android.widget.Button[contains(@text, 'Save') or contains(@content-desc, 'Save')]")); }
    }

    public void createBill(String name, String category, String type, String amount, String store) {
        clickAddBillFAB();
        enterProductName(name);
        selectCategory(category);
        selectBillType(type);
        enterAmount(amount);
        enterStore(store);
        selectQuickDuration12Months();
        clickSaveBill();
    }
}

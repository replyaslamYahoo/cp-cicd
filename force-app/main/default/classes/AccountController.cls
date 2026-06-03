public without sharing class AccountController {
    @future
    //Test1, Test2
    // This method is called from the UserController class
    // and its called in the future because the Account update is slow
    public static void updateLanguage(Id accountId, String selectedLanguage){
        // Update users Account language
        Account currentAccount = new Account(Id = accountId);
        currentAccount.Language__c = selectedLanguage;
        update currentAccount;  
    }
}
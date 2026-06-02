public without sharing class AccountController {
    @future
    // This method is called from the UserController class
    // and its called in the future because the Account update is slow
    public static void updateLanguage(Id accountId, String selectedLanguage){
        // Update users Account language
        Account currentAccount = new Account(Id = accountId);
        currentAccount.Language__c = selectedLanguage;

        //test1
        update currentAccount;  

    }
}
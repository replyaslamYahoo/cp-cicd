public without sharing  class AccountSelector {    
    public Account GetAccountById(String accountId) {
        List<Account> accounts = [
            SELECT 
            Id,           
            Language__c
            FROM Account
            WHERE Id = :accountId
        ];
        return accounts.size() > 0 ? accounts[0] : null;
    }
}
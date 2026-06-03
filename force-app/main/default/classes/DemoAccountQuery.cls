//change1, change2, change3
//change4
public without sharing class DemoAccountQuery {
    public Account getById(Id accountId) {
        List<Account> accounts = [
            SELECT Id, Name, Description
            FROM Account
            WHERE Id = :accountId
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }
}

public with sharing class DraftBoardController {

    @AuraEnabled(cacheable=true)
    public static List<Draft_Pick__c> getDraftPicks() {
        return [
            SELECT Id, Name, Overall_Pick__c, Round__c, Pick_In_Round__c,
                   Draft_Position__c, Is_Picked__c, Is_Upside_Down__c,
                   League_Member__c, League_Member__r.Name, League_Member__r.Draft_Order__c,
                   Player__c, Player__r.FirstName, Player__r.LastName,
                   Player__r.Team__c, Player__r.Bye__c,
                   Player__r.Overall_Rank__c, Player__r.Position_Rank__c,
                   Player__r.Position__c,
                   Traded_To__c, Traded_To__r.Name, Trade_Notes__c
            FROM Draft_Pick__c
            ORDER BY Overall_Pick__c ASC
            LIMIT 240
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<League_Member__c> getLeagueMembers() {
        return [
            SELECT Id, Name, Draft_Order__c, Team_Owner__c, Team_Owner__r.Name
            FROM League_Member__c
            ORDER BY Draft_Order__c ASC
            LIMIT 12
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<Contact> searchPlayers(String searchTerm) {
        String searchKey = String.escapeSingleQuotes(searchTerm) + '*';
        List<List<SObject>> results = [
            FIND :searchKey IN NAME FIELDS
            RETURNING Contact(
                Id, FirstName, LastName, Team__c, Bye__c,
                Overall_Rank__c, Position_Rank__c, Position__c
                WHERE Is_Drafted__c = false OR Is_Drafted__c = null
                ORDER BY Overall_Rank__c ASC NULLS LAST
                LIMIT 20
            )
        ];
        return (List<Contact>) results[0];
    }

    @AuraEnabled(cacheable=false)
    public static void updateContactDraftedStatus(Id contactId, Boolean isDrafted) {
        if (contactId == null) return;
        Contact c = new Contact(Id = contactId, Is_Drafted__c = isDrafted);
        update c;
    }
}

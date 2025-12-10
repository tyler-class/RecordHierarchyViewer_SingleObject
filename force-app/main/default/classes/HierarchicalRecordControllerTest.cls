@isTest
private class HierarchicalRecordControllerTest {

    /**
     * @testSetup
     * Sets up a 4-level Account hierarchy and sets OwnerId explicitly to test relationship field behavior.
     */
    @testSetup
    static void setup() {
        User owner = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Account root = new Account(Name = 'Root Account', OwnerId = owner.Id);
        insert root;

        Account child1 = new Account(Name = 'Child 1', ParentId = root.Id, OwnerId = owner.Id);
        Account child2 = new Account(Name = 'Child 2', ParentId = null, OwnerId = owner.Id); // orphan for negative test
        Account child3 = new Account(Name = 'Child 3', ParentId = child1.Id, OwnerId = owner.Id);
        Account child4 = new Account(Name = 'Child 4', ParentId = child3.Id, OwnerId = owner.Id);
        insert new List<Account> { child1, child2, child3, child4 };
    }

    /**
     * Tests full hierarchy retrieval from root down (4 levels).
     */
    @isTest
    static void testHierarchyFromRoot() {
        Account root = [SELECT Id FROM Account WHERE Name = 'Root Account' LIMIT 1];

        List<String> fields = new List<String>{ 'Name', 'OwnerId', 'ParentId' };

        List<SObject> results = HierarchicalRecordController.getHierarchicalRecords(
            'Account',
            root.Id,
            fields,
            'ParentId'
        );

        System.assertEquals(4, results.size(), 'Should return 4 records (root + 3 children)');
        Set<Id> resultIds = new Set<Id>();
        for (SObject rec : results) {
            resultIds.add((Id) rec.get('Id'));
        }

        List<Account> expected = [SELECT Id FROM Account WHERE Name IN ('Root Account', 'Child 1', 'Child 3', 'Child 4')];
        for (Account acct : expected) {
            System.assert(resultIds.contains(acct.Id), 'Expected account not found: ' + acct.Id);
        }
    }

    /**
     * Tests partial hierarchy retrieval from middle node (Child 1).
     */
    @isTest
    static void testHierarchyFromMiddleNode() {
        Account child1 = [SELECT Id FROM Account WHERE Name = 'Child 1' LIMIT 1];

        List<SObject> results = HierarchicalRecordController.getHierarchicalRecords(
            'Account',
            child1.Id,
            new List<String>{ 'ParentId' },
            'ParentId'
        );

        System.assertEquals(3, results.size(), 'Should return 3 records: Child 1, Child 3, Child 4');
    }

    /**
     * Tests safe behavior with invalid object API name.
     */
    @isTest
    static void testInvalidObjectName() {
        List<SObject> results = HierarchicalRecordController.getHierarchicalRecords(
            'InvalidObject__c',
            '001XXXXXXXXXXXX',  // fake Id
            new List<String>{ 'ParentId' },
            'ParentId'
        );

        System.assertEquals(0, results.size(), 'Should return empty list for invalid object');
    }

    /**
     * Tests buildSelectClause separately for a valid object.
     */
    @isTest
    static void testBuildSelectClauseForAccount() {
        List<String> fields = new List<String>{ 'Name', 'OwnerId', 'ParentId' };
        String selectClause = HierarchicalRecordController.buildSelectClause('Account', fields);
        System.assert(selectClause.contains('Owner.Name'), 'Should include related Owner.Name field');
        System.assert(selectClause.contains(',Name'), 'Should include Name field');
        System.assert(selectClause.contains(',OwnerId'), 'Should include OwnerId field');
    }
}
public class HierarchicalRecordController {
    /**
     * @description Retrieve hierarchical records from the topmost parent down.
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> getHierarchicalRecords(String objectName, String recordId, List<String> fields, String parentFieldAPI) {
        List<SObject> allRecords = new List<SObject>();
        Set<String> queriedIds = new Set<String>();

        try {
            SObject topParent = getTopParent(objectName, recordId, parentFieldAPI, fields);

            if (topParent != null) {
                allRecords.add(topParent);
                queriedIds.add((String) topParent.get('Id'));

                fetchChildren(objectName, (Id) topParent.get('Id'), parentFieldAPI, fields, allRecords, queriedIds);
            }
        } catch (Exception e) {
            System.debug('❌ getHierarchicalRecords error: ' + e.getMessage());
        }

        return allRecords;
    }

    /**
     * @description Walks up the tree to find the topmost parent.
     */
    private static SObject getTopParent(String objectName, String currentRecordId, String parentFieldAPI, List<String> fields) {
        SObject topParent = null;

        try {
            String fieldsInQuery = buildSelectClause(objectName, fields);
            String currentId = currentRecordId;

            while (currentId != null) {
                List<SObject> results = Database.query(
                    'SELECT Id' + fieldsInQuery + ' FROM ' + objectName + ' WHERE Id = :currentId LIMIT 1'
                );

                if (!results.isEmpty()) {
                    topParent = results[0];
                    currentId = (String) topParent.get(parentFieldAPI);
                } else {
                    currentId = null;
                }
            }
        } catch (Exception e) {
            System.debug('❌ getTopParent error: ' + e.getMessage());
        }

        return topParent;
    }

    /**
     * @description Recursively fetches all children of a given parent.
     */
    private static void fetchChildren(String objectName, Id parentId, String parentFieldAPI, List<String> fields, List<SObject> allRecords, Set<String> queriedIds) {
        try {
            String fieldsInQuery = buildSelectClause(objectName, fields);
            List<SObject> childRecords = Database.query(
                'SELECT Id' + fieldsInQuery + ' FROM ' + objectName + ' WHERE ' + parentFieldAPI + ' = :parentId'
            );

            for (SObject child : childRecords) {
                String childId = (String) child.get('Id');

                if (!queriedIds.contains(childId)) {
                    allRecords.add(child);
                    queriedIds.add(childId);
                    fetchChildren(objectName, (Id) child.get('Id'), parentFieldAPI, fields, allRecords, queriedIds);
                }
            }
        } catch (Exception e) {
            System.debug('❌ fetchChildren error: ' + e.getMessage());
        }
    }

    /**
     * @description Builds a SELECT clause for the SOQL query.
     */
    public static String buildSelectClause(String objectName, List<String> fields) {
        String fieldsToQuery = '';

        try {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
            if (sObjType != null) {
                Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

                for (String field : fields) {
                    if (fieldMap.containsKey(field)) {
                        fieldsToQuery += ',' + field;

                        Schema.DescribeFieldResult fieldDesc = fieldMap.get(field).getDescribe();
                        if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
                            fieldsToQuery += ',' + fieldDesc.getRelationshipName() + '.Name';
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('❌ buildSelectClause error: ' + e.getMessage());
        }

        return fieldsToQuery;
    }
}
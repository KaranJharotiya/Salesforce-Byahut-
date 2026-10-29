/**
 * BusinessProgressController
 * ------------------------------------------------------------------
 * Single, generic controller behind the whole Business Progress hub.
 * Replaces the earlier SalesOrderProgressController / QuotationProgressController /
 * ChallanProgressController / BusinessAccessController with one class,
 * driven by a small per-module config map + dynamic SOQL.
 *
 * Every method takes a `moduleKey` ('SalesOrder' | 'Quotation' | 'Challan')
 * and looks up that module's object/field names from MODULE_CONFIG below.
 *
 * ASSUMPTIONS TO ADJUST FOR YOUR ORG:
 *  - Object/field API names and status lists in MODULE_CONFIG
 *  - Profile -> module access in PROFILE_MODULE_MAP
 *  - Admin check: Profile name == 'System Administrator'
 *
 * To add a fourth module later: add one entry to MODULE_CONFIG (and to
 * PROFILE_MODULE_MAP for whichever profiles should see it) - nothing
 * else in this class or in the LWC needs to change.
 * ------------------------------------------------------------------
 */
public with sharing class BusinessProgressController {

    private class ModuleConfig {
        String objectApiName;
        String dateField;
        String statusField;
        String closedStatus;
        String label;
        String amountField;
        // When set, every query for this module is hard-filtered to this one
        // status value (e.g. Accounts should only ever see Challans that are
        // currently 'Packing Completed/Invoice Pending'), on top of the
        // normal OwnerId scoping.
        String restrictToStatus;

        ModuleConfig(String objectApiName, String dateField, String statusField, String closedStatus, String label, String amountField) {
            this(objectApiName, dateField, statusField, closedStatus, label, amountField, null);
        }

        ModuleConfig(String objectApiName, String dateField, String statusField, String closedStatus, String label, String amountField, String restrictToStatus) {
            this.objectApiName = objectApiName;
            this.dateField = dateField;
            this.statusField = statusField;
            this.closedStatus = closedStatus;
            this.label = label;
            this.amountField = amountField;
            this.restrictToStatus = restrictToStatus;
        }
    }

    // Status picklist values are NOT listed here - they're read from the
    // field's describe at runtime (see getStatusSteps), so the UI always
    // reflects whatever is actually configured on the picklist.
    //
    // closedStatus = which value counts as "complete" for the Team
    // Progress percentage. Leave it null to fall back to the last active
    // picklist value on the field.
    private static final Map<String, ModuleConfig> MODULE_CONFIG = new Map<String, ModuleConfig>{
        'SalesOrder' => new ModuleConfig(
            'Sales_Order__c', 'Sales_Order_Date__c', 'Status__c', 'Complete', 'Sales Orders', 'Grand_Total_With_GST__c'
        ),
        'Quotation' => new ModuleConfig(
            'Quotation__c', 'CreatedDate', 'Status__c', 'Ordered', 'Quotations', 'Grand_Total_With_GST__c'
        ),
        'Challan' => new ModuleConfig(
            'Challan__c', 'CreatedDate', 'Status__c', 'Packing Completed', 'Challans', 'Total_Items__c'
        ),
        // Accounts only ever needs to work Challans that are currently
        // awaiting an invoice - hard filtered via restrictToStatus below,
        // on top of the normal OwnerId (assigned-to-me) scoping.
        'ChallanInvoicePending' => new ModuleConfig(
            'Challan__c', 'CreatedDate', 'Status__c', 'Packing Completed/Invoice Pending', 'Invoice Pending Challans', 'Total_Items__c',
            'Packing Completed/Invoice Pending'
        ),
        'DeliveryDetail' => new ModuleConfig(
            'Delivery_Detail__c', 'CreatedDate', 'Delivery_Status__c', null, 'Delivery Details', 'Promised_Items__c'
        )
    };

    // TODO: replace these placeholder Profile names with your org's real ones.
    private static final Map<String, Set<String>> PROFILE_MODULE_MAP = new Map<String, Set<String>>{
        'Sales Team'     => new Set<String>{ 'SalesOrder', 'Quotation' },
        'Operations Team' => new Set<String>{ 'SalesOrder', 'Challan' },
        'Warehouse Team' => new Set<String>{ 'Challan' },
        'Sales Executive'     => new Set<String>{ 'SalesOrder', 'Quotation' },
        'Operations Executive' => new Set<String>{ 'SalesOrder', 'Challan' },
        'Accounts' => new Set<String>{ 'ChallanInvoicePending' },
        'Station Staff' => new Set<String>{ 'Challan' },
        'Logistics Team Manager' => new Set<String>{ 'DeliveryDetail' }
    };

    // private static void init(){
    //     MODULE_CONFIG = new Map<String, ModuleConfig>{
    //         'SalesOrder' => new ModuleConfig(
    //             'Sales_Order__c', 'Order_Date__c', 'Status__c', 'Closed', 'Sales Orders'
    //         ),
    //         'Quotation' => new ModuleConfig(
    //             'Quotation__c', 'Quotation_Date__c', 'Status__c', 'Accepted', 'Quotations'
    //         ),
    //         'Challan' => new ModuleConfig(
    //             'Challan__c', 'Challan_Date__c', 'Status__c', 'Delivered', 'Challans'
    //         )
    //     };
    // }

    // ---------------------------------------------------------------
    // Access
    // ---------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        User u;
        String profileName;
        if (Schema.sObjectType.Profile.isAccessible()){
            u = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            profileName = u.Profile.Name;
        }else{
            u = [SELECT User_Profile_Name__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            profileName = u.User_Profile_Name__c;
        }
        return profileName == 'System Administrator';
    }

    // Fixed display order for tabs, regardless of Set iteration order.
    private static final List<String> MODULE_ORDER = new List<String>{ 'SalesOrder', 'Quotation', 'Challan', 'ChallanInvoicePending', 'DeliveryDetail' };

    @AuraEnabled(cacheable=true)
    public static AccessInfo getMyAccess() {
        User u;
        String profileName;
        if (Schema.sObjectType.Profile.isAccessible()){
            u = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            profileName = u.Profile.Name;
        }else{
            u = [SELECT User_Profile_Name__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            profileName = u.User_Profile_Name__c;
        } 

        AccessInfo info = new AccessInfo();
        info.profileName = profileName;
        info.isAdmin = (profileName == 'System Administrator');

        Set<String> allowedKeys;
        if (info.isAdmin) {
            allowedKeys = MODULE_CONFIG.keySet();
        } else if (PROFILE_MODULE_MAP.containsKey(profileName)) {
            allowedKeys = PROFILE_MODULE_MAP.get(profileName);
        } else {
            allowedKeys = new Set<String>();
        }

        info.modules = new List<ModuleInfo>();
        for (String key : MODULE_ORDER) {
            if (!allowedKeys.contains(key)) {
                continue;
            }
            ModuleConfig cfg = MODULE_CONFIG.get(key);
            ModuleInfo mi = new ModuleInfo();
            mi.key = key;
            mi.label = cfg.label;
            mi.closedStatusLabel = resolveClosedStatus(cfg);
            info.modules.add(mi);
        }
        return info;
    }

    // ---------------------------------------------------------------
    // Per-module data (moduleKey-driven, dynamic SOQL)
    // ---------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<String> getStatusSteps(String moduleKey) {
        return describeStatusValues(getConfig(moduleKey));
    }

    /**
     * Reads the active picklist values off the module's Status field via
     * Schema describe, in the order they're defined on the field. Falls
     * back to an empty list if the field isn't a picklist or isn't
     * accessible to the running user.
     *
     * Results are memoized per transaction so repeated calls (e.g. one
     * per module tab) don't re-describe the same field.
     */
    private static Map<String, List<String>> statusValueCache = new Map<String, List<String>>();

    private static List<String> describeStatusValues(ModuleConfig cfg) {
        String cacheKey = cfg.objectApiName + '.' + cfg.statusField;
        if (statusValueCache.containsKey(cacheKey)) {
            return statusValueCache.get(cacheKey);
        }

        List<String> values = new List<String>();

        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(cfg.objectApiName);
        if (sobjType != null) {
            Schema.SObjectField fld = sobjType.getDescribe().fields.getMap().get(cfg.statusField);
            if (fld != null) {
                Schema.DescribeFieldResult dfr = fld.getDescribe();
                if (dfr.isAccessible() &&
                    (dfr.getType() == Schema.DisplayType.PICKLIST || dfr.getType() == Schema.DisplayType.MULTIPICKLIST)) {
                    for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
                        if (entry.isActive()) {
                            values.add(entry.getValue());
                        }
                    }
                }
            }
        }

        statusValueCache.put(cacheKey, values);
        return values;
    }

    // private static List<String> describeStatusValues(String objectApiName, String statusField) {
    //     String cacheKey = objectApiName + '.' + statusField;
    //     if (statusValueCache.containsKey(cacheKey)) {
    //         return statusValueCache.get(cacheKey);
    //     }

    //     List<String> values = new List<String>();

    //     Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
    //     if (sobjType != null) {
    //         Schema.SObjectField fld = sobjType.getDescribe().fields.getMap().get(statusField);
    //         if (fld != null) {
    //             Schema.DescribeFieldResult dfr = fld.getDescribe();
    //             if (dfr.isAccessible() &&
    //                 (dfr.getType() == Schema.DisplayType.PICKLIST || dfr.getType() == Schema.DisplayType.MULTIPICKLIST)) {
    //                 for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
    //                     if (entry.isActive()) {
    //                         values.add(entry.getValue());
    //                     }
    //                 }
    //             }
    //         }
    //     }

    //     return values;
    // }

    /**
     * Which status counts as "complete" for the Team Progress percentage.
     * Uses the configured value when it's still a live picklist entry;
     * otherwise falls back to the last active value on the field, so the
     * percentage keeps working if someone renames the final stage.
     */
    private static String resolveClosedStatus(ModuleConfig cfg) {
        List<String> values = describeStatusValues(cfg);
        if (String.isNotBlank(cfg.closedStatus) && values.contains(cfg.closedStatus)) {
            return cfg.closedStatus;
        }
        return values.isEmpty() ? null : values[values.size() - 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordWrapper> getMyRecords(String moduleKey) {
        ModuleConfig cfg = getConfig(moduleKey);
        Id currentUserId = UserInfo.getUserId();
        String restrictStatus = cfg.restrictToStatus;
        String query = 'SELECT Id, Name, ' + cfg.statusField + ', ' + cfg.dateField + ', ' + cfg.amountField + ', OwnerId, Owner.Name ' +
            'FROM ' + cfg.objectApiName + ' WHERE OwnerId = :currentUserId ' +
            (String.isNotBlank(restrictStatus) ? 'AND ' + cfg.statusField + ' = :restrictStatus ' : '') +
            'ORDER BY ' + cfg.dateField + ' DESC LIMIT 200';
        return wrap(Database.query(query), cfg);
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordWrapper> getRecordsByOwner(String moduleKey, Id ownerId) {
        if (!isCurrentUserAdmin()) {
            throw new AuraHandledException('You do not have permission to view this data.');
        }
        ModuleConfig cfg = getConfig(moduleKey);
        String restrictStatus = cfg.restrictToStatus;
        String query = 'SELECT Id, Name, ' + cfg.statusField + ', ' + cfg.dateField + ', ' + cfg.amountField + ', OwnerId, Owner.Name ' + (moduleKey == 'DeliveryDetail' ? ', Expected_Delivery_Date__c, Delivered_Date__c ' : '') + 
            'FROM ' + cfg.objectApiName + ' WHERE OwnerId = :ownerId ' +
            (String.isNotBlank(restrictStatus) ? 'AND ' + cfg.statusField + ' = :restrictStatus ' : '') +
            'ORDER BY ' + cfg.dateField + ' DESC LIMIT 200';
        return wrap(Database.query(query), cfg);
    }

    @AuraEnabled(cacheable=true)
    public static List<UserSummary> getTeamSummary(String moduleKey) {
        if (!isCurrentUserAdmin()) {
            throw new AuraHandledException('You do not have permission to view this data.');
        }
        ModuleConfig cfg = getConfig(moduleKey);
        String closedStatus = resolveClosedStatus(cfg);
        String restrictStatus = cfg.restrictToStatus;
        String query = 'SELECT OwnerId ownerId, Owner.Name ownerName, ' + cfg.statusField + ' status, COUNT(Id) cnt ' +
            'FROM ' + cfg.objectApiName +
            (String.isNotBlank(restrictStatus) ? ' WHERE ' + cfg.statusField + ' = :restrictStatus' : '') +
            ' GROUP BY OwnerId, Owner.Name, ' + cfg.statusField;

        Map<Id, UserSummary> summaryByOwner = new Map<Id, UserSummary>();
        for (AggregateResult ar : Database.query(query)) {
            Id ownerId = (Id) ar.get('ownerId');
            if (!summaryByOwner.containsKey(ownerId)) {
                UserSummary s = new UserSummary();
                s.userId = ownerId;
                s.userName = (String) ar.get('ownerName');
                s.totalRecords = 0;
                s.closedRecords = 0;
                summaryByOwner.put(ownerId, s);
            }
            UserSummary summary = summaryByOwner.get(ownerId);
            Integer count = (Integer) ar.get('cnt');
            String status = (String) ar.get('status');

            summary.totalRecords += count;
            if (closedStatus != null && status == closedStatus) {
                summary.closedRecords += count;
            }
        }

        List<UserSummary> results = summaryByOwner.values();
        for (UserSummary s : results) {
            s.completionPercent = s.totalRecords == 0
                ? 0
                : Math.round((Decimal.valueOf(s.closedRecords) / Decimal.valueOf(s.totalRecords)) * 100);
        }
        results.sort();
        return results;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    private static ModuleConfig getConfig(String moduleKey) {
        if (!MODULE_CONFIG.containsKey(moduleKey)) {
            throw new AuraHandledException('Unknown module: ' + moduleKey);
        }
        return MODULE_CONFIG.get(moduleKey);
    }

    private static List<RecordWrapper> wrap(List<SObject> records, ModuleConfig cfg) {
        List<RecordWrapper> result = new List<RecordWrapper>();
        for (SObject r : records) {
            RecordWrapper w = new RecordWrapper();
            w.id = (Id) r.get('Id');
            w.orderNumber = (String) r.get('Name');
            w.status = (String) r.get(cfg.statusField);
            w.orderDate = (DateTime) r.get(cfg.dateField);
            SObject ownerRec = r.getSObject('Owner');
            w.ownerName = ownerRec != null ? (String) ownerRec.get('Name') : null;

            if(cfg.objectApiName == 'Challan__c'){
                w.totalItems = (String) r.get(cfg.amountField);
            }else {
                w.amount = (Decimal) r.get(cfg.amountField);
            }

            if(cfg.objectApiName == 'Delivery_Detail__c'){
                w.expectedDeliveryDate = (Date) r.get('Expected_Delivery_Date__c');
                w.deliveryDate = (Date) r.get('Delivered_Date__c');
            }

            result.add(w);
        }
        return result;
    }

    // ---------------------------------------------------------------
    // Wrapper classes
    // ---------------------------------------------------------------

    public class AccessInfo {
        @AuraEnabled public String profileName;
        @AuraEnabled public Boolean isAdmin;
        @AuraEnabled public List<ModuleInfo> modules;
    }

    public class ModuleInfo {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String closedStatusLabel;
    }

    public class RecordWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime orderDate;
        @AuraEnabled public Date expectedDeliveryDate;
        @AuraEnabled public Date deliveryDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String totalItems;
        
    }

    public class UserSummary implements Comparable {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer closedRecords;
        @AuraEnabled public Decimal completionPercent;

        public Integer compareTo(Object other) {
            UserSummary o = (UserSummary) other;
            return userName > o.userName ? 1 : (userName < o.userName ? -1 : 0);
        }
    }
}
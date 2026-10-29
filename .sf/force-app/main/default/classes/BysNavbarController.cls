public without sharing class BysNavbarController {
    
    private static final String API_VERSION = 'v67.0';
    
    public class NotificationResponse {
        
        @AuraEnabled
        public List<NotificationItem> notifications = new List<NotificationItem>();
        
        @AuraEnabled
        public Integer unreadCount = 0;
    }

    public class NotificationItem {
        
        @AuraEnabled
        public String id;
        
        @AuraEnabled
        public String title;
        
        @AuraEnabled
        public String body;
        
        @AuraEnabled
        public Boolean read;
        
        @AuraEnabled
        public Boolean seen;
        
        @AuraEnabled
        public String targetId;
        
        @AuraEnabled
        public String notificationType;
        
        @AuraEnabled
        public String imageUrl;
        
        @AuraEnabled
        public Datetime lastModified;
        
        @AuraEnabled
        public Datetime activityDate;
    }

    @AuraEnabled(cacheable=false)
    public static NotificationResponse getNotifications() {
        
        System.debug('=== getNotifications called by User: ' + UserInfo.getUserId() + ' | ' + UserInfo.getName());
        System.debug('=== User Type: ' + UserInfo.getUserType());
        
        String response = callAPI(
            'GET',
            '/services/data/' + API_VERSION + '/connect/notifications',
            null
        );
        
        System.debug('=== getNotifications raw response: ' + response);
        
        NotificationResponse result = parseResponse(response);
        
        System.debug('=== getNotifications parsed count: ' + result.notifications.size() + ' | unreadCount: ' + result.unreadCount);
        
        return result;
    }
    
    @AuraEnabled(cacheable=false)
    public static NotificationResponse getOlderNotifications(String before) {
        
        System.debug('=== getOlderNotifications called with before=' + before);
        
        String response = callAPI(
            'GET',
            '/services/data/' + API_VERSION +
            '/connect/notifications?before=' +
            EncodingUtil.urlEncode(before,'UTF-8'),
            null
        );
        
        System.debug('=== getOlderNotifications raw response: ' + response);
        
        return parseResponse(response);
    }
    
    @AuraEnabled
    public static void markNotificationRead(String notificationId){
        
        System.debug('=== markNotificationRead called for id: ' + notificationId);
        
        callAPI(
            'PATCH',
            '/services/data/' + API_VERSION +
            '/connect/notifications/' +
            notificationId,
            '{"read":true}'
        );
    }
    
    @AuraEnabled
    public static void markAllRead(){
        
        String nowIso = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        
        Map<String,Object> body = new Map<String,Object>();
        body.put('before', nowIso);
        body.put('read', true);
        
        System.debug('=== markAllRead before: ' + nowIso);
        
        callAPI(
            'PATCH',
            '/services/data/' + API_VERSION + '/connect/notifications',
            JSON.serialize(body)
        );
    }
    
    private static String callAPI(
        String method,
        String uri,
        String body
    ){
        
        String endpoint = URL.getOrgDomainUrl().toExternalForm() + uri;
        
        System.debug('=== callAPI method: ' + method);
        System.debug('=== callAPI endpoint: ' + endpoint);
        System.debug('=== callAPI sessionId present: ' + (UserInfo.getSessionId() != null));
        System.debug('=== callAPI sessionId length: ' + (UserInfo.getSessionId() != null ? UserInfo.getSessionId().length() : 0));
        
        HttpRequest req = new HttpRequest();
        
        req.setMethod(method);
        req.setEndpoint(endpoint);
        
        req.setHeader(
            'Authorization',
            'Bearer ' + UserInfo.getSessionId()
        );
        
        req.setHeader(
            'Content-Type',
            'application/json'
        );
        
        if(body != null){
            System.debug('=== callAPI request body: ' + body);
            req.setBody(body);
        }
        
        HttpResponse res;
        
        try {
            res = new Http().send(req);
        } catch (Exception calloutEx) {
            System.debug('=== callAPI EXCEPTION during send: ' + calloutEx.getMessage());
            System.debug('=== callAPI EXCEPTION type: ' + calloutEx.getTypeName());
            throw new AuraHandledException('Callout failed: ' + calloutEx.getMessage());
        }
        
        System.debug('=== callAPI status code: ' + res.getStatusCode());
        System.debug('=== callAPI status: ' + res.getStatus());
        System.debug('=== callAPI response body: ' + res.getBody());
        System.debug('=== callAPI response headers - Content-Type: ' + res.getHeader('Content-Type'));
        
        if(res.getStatusCode() >= 300){
            System.debug('=== callAPI FAILED with status ' + res.getStatusCode() + ' body: ' + res.getBody());
            throw new AuraHandledException(res.getBody());
        }
        
        return res.getBody();
    }
    
    private static NotificationResponse parseResponse(String jsonResponse){
        
        NotificationResponse response = new NotificationResponse();
        
        if (String.isBlank(jsonResponse)) {
            System.debug('=== parseResponse: jsonResponse is blank/null');
            return response;
        }
        
        Map<String,Object> root;
        
        try {
            root = (Map<String,Object>)JSON.deserializeUntyped(jsonResponse);
        } catch (Exception parseEx) {
            System.debug('=== parseResponse EXCEPTION: ' + parseEx.getMessage());
            System.debug('=== parseResponse raw input was: ' + jsonResponse);
            return response;
        }
        
        System.debug('=== parseResponse root keys: ' + root.keySet());
        
        List<Object> rows =
            (List<Object>)root.get('notifications');
        
        if(rows == null){
            System.debug('=== parseResponse: "notifications" key missing or null in response');
            return response;
        }
        
        System.debug('=== parseResponse row count: ' + rows.size());
        
        for(Object obj : rows){
            
            Map<String,Object> row =
                (Map<String,Object>)obj;
            
            NotificationItem item = new NotificationItem();
            
            item.id = (String)row.get('id');
            item.title = (String)row.get('messageTitle');
            item.body = (String)row.get('messageBody');
            item.read = (Boolean)row.get('read');
            item.seen = (Boolean)row.get('seen');
            item.targetId = (String)row.get('target');
            item.notificationType = (String)row.get('type');
            item.imageUrl = (String)row.get('image');
            
            if(row.containsKey('lastModified')){
                item.lastModified =
                    Datetime.valueOfGmt(
                        ((String)row.get('lastModified'))
                        .replace('T',' ')
                        .replace('Z','')
                    );
            }
            
            if(row.containsKey('mostRecentActivityDate')){
                item.activityDate =
                    Datetime.valueOfGmt(
                        ((String)row.get('mostRecentActivityDate'))
                        .replace('T',' ')
                        .replace('Z','')
                    );
            }
            
            if(item.read == false){
                response.unreadCount++;
            }
            
            response.notifications.add(item);
        }
        
        System.debug('=== parseResponse final unreadCount: ' + response.unreadCount);
        
        return response;
    }
}
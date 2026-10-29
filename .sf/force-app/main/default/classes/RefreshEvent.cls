public class RefreshEvent {
    
    public static void publishEvent() {
        Refresh_Event__e eventMsg = new Refresh_Event__e(
        );
        
        Database.SaveResult result = EventBus.publish(eventMsg);
        
        if (result.isSuccess()) {
            System.debug('Event Published Successfully');
        } else {
            System.debug('Event Failed');
        }
    }
}
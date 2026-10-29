public class SendEmail {
    
    public static void sendEmail(List<String> toEmails, String subject, String body) {
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        mail.setToAddresses(toEmails);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setHtmlBody(body);
        
        
        try{
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('Emai has been sent');
        }catch(Exception e){
            System.debug('error while sending email => '+ e.getMessage() + '  '+ e.getStackTraceString());
        }
    }
}
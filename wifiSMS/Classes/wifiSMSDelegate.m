#import "wifiSMSDelegate.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import <sqlite3.h>

//3.0 MsgCenter
@interface CTMessageCenter : NSObject                                                                                  
{                                                                                                                      
}               

- (BOOL)sendSMSWithText:(id)arg1 serviceCenter:(id)arg2 toAddress:(id)arg3;

@end 


static void readF(sqlite3_context *context, int argc, sqlite3_value **argv) { return ;}

static void callback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	NSString *IncomingNotification = [NSString stringWithFormat:@"%@", name];
	
	//NSLog(@"Notification: %@", name);
	
	/* this works */
	/*
	 if ([@"kCTMessageReceivedNotification" isEqualToString:IncomingNotification]) {
	 
	 NSLog(@"Message Got Notification");
	 
	 //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	 CFShow(userInfo);
	 if (!userInfo) return;
	 
	 NSDictionary *info = (NSDictionary *)userInfo;
	 
	 CFNumberRef msgID = (CFNumberRef)[info objectForKey:@"kCTMessageIdKey"];
	 int result;
	 CFNumberGetValue((CFNumberRef)msgID, kCFNumberSInt32Type, &result);
	 
	 id incMsg; 
	 Class CTMessageCenter = NSClassFromString(@"CTMessageCenter");
	 id mc = [CTMessageCenter sharedMessageCenter];
	 incMsg = [mc incomingMessageWithId: result];
	 int mType = (int)[incMsg messageType];
	 NSString *sender;
	 NSString *smsText;
	 if (mType == 1)
	 {
	 id phonenumber = [incMsg sender];
	 sender = [phonenumber canonicalFormat];
	 id incMsgPart = [[incMsg items] objectAtIndex:0];
	 NSData *smsData = [incMsgPart data];
	 smsText = [[NSString alloc] initWithData:smsData encoding:NSUTF8StringEncoding];
	 }
	 NSLog(@"Sender: %@", sender);
	 NSLog(@"Text: %@", smsText);
	 //[pool drain];
	 
	 
	 }
	 */
	/* end test */
	
	if ([@"kCTMessageSentNotification" isEqualToString:IncomingNotification]) {
		
		NSLog(@"Message Sent Notification");
		
		NSString *path = [myAppPath stringByAppendingString:@"SMS.plist"];
        NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
		NSString *postStr = @"";
		
        postStr = [plistDict objectForKey:@"SMSQueue"];
		
		
		if ([postStr isEqualToString:@""]) {
			NSLog(@"Empty Notifcation");
			return;
		}
				
		int index = [postStr rangeOfString:@"&"].location;
		NSString *Phone = [postStr substringToIndex:index];
		Phone = [Phone substringFromIndex:6];
		
		index = [postStr rangeOfString:@"msg="].location + 4;
		NSString *msg = [postStr substringFromIndex: index];
		index = [msg rangeOfString:@"&"].location;
		msg = [msg substringToIndex: index];
		
		index = [postStr rangeOfString:@"pid="].location + 4;
		NSString *pid = [postStr substringFromIndex: index];
		index = [pid rangeOfString:@"&"].location;
		pid = [pid substringToIndex: index];
		
		index = [postStr rangeOfString:@"grp="].location + 4;
		NSString *grp = [postStr substringFromIndex: index];
		index = [grp rangeOfString:@"&"].location;
		grp = [grp substringToIndex: index];
		
		index = [postStr rangeOfString:@"Country="].location + 8;
		NSString *Country = [postStr substringFromIndex: index];
		index = [Country rangeOfString:@"&"].location;
		Country = [Country substringToIndex: index];
		
		
		//Send SMS
		msg = [msg stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString *DT = @"";
		
		DT = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];			
		

		
		if ([grp isEqualToString:@"0"] || [pid isEqualToString:@""]) {
			return;
		}
		
		BOOL wasAddedToDB = NO;
		int Attempt = 0;
		
		while (Attempt <= 3 && wasAddedToDB == NO) {			
			Attempt++;
			NSLog(@"Adding to SMS.db Attempt %d", Attempt); 

			sqlite3 *database;
			if(sqlite3_open([@"/private/var/mobile/Library/SMS/sms.db" UTF8String], &database) == SQLITE_OK) {
				const char *fn_name = "read"; 
				sqlite3_stmt *addStatement;
				
				sqlite3_create_function(database, fn_name, 1, SQLITE_INTEGER, nil, readF, nil, nil); 
				const char *sql = "INSERT INTO message (address,date,text,flags,replace,svc_center,group_id,association_id,height,UIFlags,version,subject,country,headers,recipients,read) VALUES (?,?,?,'3','0',NULL,?,'0','0','0','0',NULL,?,NULL,NULL,'1')";
				
				if(sqlite3_prepare_v2(database, sql, -1, &addStatement, NULL) != SQLITE_OK) {
					NSLog(@"Error while creating add statement: %s", sqlite3_errmsg(database));
				} else {
					sqlite3_bind_text(addStatement, 1, [pid UTF8String], -1, SQLITE_TRANSIENT);
					sqlite3_bind_text(addStatement, 2, [DT UTF8String], -1, SQLITE_TRANSIENT);
					sqlite3_bind_text(addStatement, 3, [msg UTF8String], -1, SQLITE_TRANSIENT);
					sqlite3_bind_text(addStatement, 4, [grp UTF8String], -1, SQLITE_TRANSIENT);
					sqlite3_bind_text(addStatement, 5, [Country UTF8String], -1, SQLITE_TRANSIENT);
					
					if(SQLITE_DONE != sqlite3_step(addStatement)) {
						NSLog(@"Error while inserting data: %s", sqlite3_errmsg(database));
					} else {
						sqlite3_reset(addStatement);
						wasAddedToDB = YES;
						//sqlite3_finalize(addStatement); //is needed i dunno...
					}
				}
			}
			sqlite3_close(database);
			
			if (wasAddedToDB == NO) {
				sleep(2);
			} else {
				NSLog(@"Adding on %d Attempt", Attempt);
			}
			
		}

		if (wasAddedToDB == NO) {
			NSLog(@"Sent, but Failed to add to SMS.db max Attempts %d exceeded", Attempt);
		}
		
		
		[plistDict setValue:@"" forKey:@"SMSQueue"];
		[plistDict writeToFile:path atomically: YES];
		[plistDict release];
		
	}
    return;
}



@implementation wifiSMSDelegate


-(void) keepApplicationRunning:(NSTimer *) timer
{
	
}

//this function is to only be called once.
-(void) start
{
	myAppPath = @"/private/var/mobile/Library/WifiSMS/";	
		
	NSString *ppath = [myAppPath stringByAppendingString:@"WebServer.plist"];

	NSMutableDictionary* settingsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:ppath];
	
	NSString *pUserName = @"";
	NSString *pPassword = @"";
	NSString *pPort= @"";
	
	pUserName = [pPassword stringByAppendingString:[settingsDict objectForKey:@"UserName"]];
	pPassword = [pPassword stringByAppendingString:[settingsDict objectForKey:@"Password"]];
	pPort = [pPort stringByAppendingString:[settingsDict objectForKey:@"Port"]];
	
	[settingsDict release];
	
	/* Clear SMS Queue */
	NSString *Spath = [myAppPath stringByAppendingString:@"SMS.plist"];
	NSMutableDictionary *SMSplistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:Spath];
	[SMSplistDict setValue:@"" forKey:@"SMSQueue"];
	[SMSplistDict writeToFile:Spath atomically: YES];
	[SMSplistDict release];
	
	
	wifiUserName = pUserName;
	wifiPassword = pPassword;
	wifiPort = pPort;
	
	NSError *error;
	
	httpServer = [HTTPServer new];
	[httpServer setType:@"_http._tcp."];
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	
	NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:webPath]];
	//[localhostAddresses performSelectorInBackground:@selector(list) withObject:nil];	
	
	//Start server	
	[httpServer setPort:[pPort integerValue] ];
	

	
	if(![httpServer start:&error])
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
	

	//Clear tmp directory
	[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/WifiSMS/" error:NULL];
	
	
	NSFileManager *fileManager= [NSFileManager defaultManager]; 
	if(![fileManager fileExistsAtPath:@"/tmp/WifiSMS/" isDirectory: YES])
		if(![fileManager createDirectoryAtPath:@"/tmp/WifiSMS/" withIntermediateDirectories:YES attributes:nil error:NULL])
			NSLog(@"Error: Create tmp folder failed /tmp/WifiSMS/");
	
	//Clear Plist data
	NSString *path = [myAppPath stringByAppendingString:@"SMS.plist"];
	NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:path];	
	[plistDict setValue:@"" forKey:@"Phone"];
	[plistDict setValue:@"" forKey:@"msg"];
	[plistDict setValue:@"" forKey:@"pid"];
	[plistDict setValue:@"" forKey:@"grp"];
	[plistDict setValue:@"" forKey:@"DT"];
	[plistDict setValue:@"" forKey:@"rand"];
	[plistDict setValue:@"" forKey:@"Status"];
	[plistDict setValue:@"" forKey:@"Country"];
	[plistDict writeToFile:path atomically: YES];
	[plistDict release];
	
	id ct = CTTelephonyCenterGetDefault();
	CTTelephonyCenterAddObserver(ct, NULL, callback, NULL, NULL, CFNotificationSuspensionBehaviorHold);		

}


-(void) dealloc
{
	[httpServer release];
	[super dealloc];
}



@end

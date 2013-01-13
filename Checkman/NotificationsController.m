#import "NotificationsController.h"
#import <objc/runtime.h>
#import "CustomNotifier.h"
#import "CustomNotification.h"
#import "GrowlNotifier.h"
#import "CheckCollection.h"
#import "Check.h"

// Make compiler happy
@interface NotificationsController (FakeNSUserNotification)
+ (id)defaultUserNotificationCenter;
- (void)setDeliveryDate:(NSDate *)date;
- (void)scheduleNotification:(id)notification;
@end


@interface NotificationsController ()
    <CheckCollectionDelegate, GrowlNotifierDelegate>
@property (nonatomic, strong) CustomNotifier *custom;
@property (nonatomic, strong) GrowlNotifier *growl;
@property (nonatomic, strong) CheckCollection *checks;
@end

@implementation NotificationsController

@synthesize
    delegate = _delegate,
    allowCustom = _allowCustom,
    allowGrowl = _allowGrowl,
    allowNotificationCenter = _allowNotificationCenter,
    custom = _custom,
    growl = _growl,
    checks = _checks;

- (id)init {
    if (self = [super init]) {
        self.custom = [[CustomNotifier alloc] init];
        self.growl = [[GrowlNotifier alloc] init];
        self.growl.delegate = self;

        self.checks = [[CheckCollection alloc] init];
        self.checks.delegate = self;
    }
    return self;
}

- (void)addCheck:(Check *)check {
    [self.checks addCheck:check];
}

- (void)removeCheck:(Check *)check {
    [self.checks removeCheck:check];
}

#pragma mark - CheckCollectionDelegate

- (void)checkCollection:(CheckCollection *)collection
        didUpdateStatusFromCheck:(Check *)check {}

- (void)checkCollection:(CheckCollection *)collection
        didUpdateChangingFromCheck:(Check *)check {}

- (void)checkCollection:(CheckCollection *)collection
        checkDidChangeStatus:(Check *)check {
    if (!check.isAfterFirstRun) {
        [self _showNotificationForCheck:check];
    }
}

#pragma mark -

- (void)_showNotificationForCheck:(Check *)check {
    if (self.allowCustom) {
        [self _showCustomNotificationForCheck:check];
    } else if (self.allowGrowl && self.growl.canShowNotification) {
        [self.growl showNotificationForCheck:check];
    } else if (self.allowNotificationCenter && self._canShowCenterNotification) {
        [self _showCenterNotificationForCheck:check];
    } else NSLog(@"NotificationsController - swallowed notification");
}

#pragma mark - Custom notifications

- (void)_showCustomNotificationForCheck:(Check *)check {
    CustomNotification *notification = [[CustomNotification alloc] init];
    notification.name = check.statusNotificationName;
    notification.status = check.statusNotificationText;
    notification.color = check.statusNotificationColor;
    [self.custom showNotification:notification];
}

#pragma mark - GrowlNotifierDelegate

- (void)growlNotifier:(GrowlNotifier *)notifier
        didClickOnCheckWithTag:(NSInteger)tag {
    Check *check = [self.checks checkWithTag:tag];
    [self.delegate notificationsController:self didActOnCheck:check];
}

#pragma mark - OS X Notification Center

- (BOOL)_canShowCenterNotification {
    return objc_getClass("NSUserNotification") != nil;
}

- (void)_showCenterNotificationForCheck:(Check *)check {
    NSLog(@"NotificationsController - user notification: %@", check.statusNotificationName);

    id notification = [[NSClassFromString(@"NSUserNotification") alloc] init];
    [notification setTitle:check.statusNotificationName];
    [notification setInformativeText:check.statusNotificationText];
    [notification setDeliveryDate:[NSDate dateWithTimeIntervalSinceNow:1]];

    id notificationCenter = NSClassFromString(@"NSUserNotificationCenter");
    [[notificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
}
@end

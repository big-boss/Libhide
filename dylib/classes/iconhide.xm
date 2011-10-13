//
//  Wallpaper.mm
//  Wallpaper
//
//  Created by Public Nuisance on 6/25/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//
//  MobileSubstrate, libsubstrate.dylib, and substrate.h are
//  created and copyrighted by Jay Freeman a.k.a saurik and 
//  are protected by various means of open source licensing.
//
//

#include <substrate.h>
#include <time.h>
#include <notify.h>

//*******************************************************************************************************
// #defines
//*******************************************************************************************************
#define IH_VERSION "2.0.6-1"
#define HIDLIBPATH "/var/mobile/Library/LibHide/hidden.plist"

#define SYS_VER_2(_x) (_x >= 2.0 && _x < 3.0) ? YES : NO
#define SYS_VER_3(_x) (_x >= 3.0 && _x < 4.0) ? YES : NO
#define SYS_VER_4(_x) (_x >= 4.0 && _x < 5.0) ? YES : NO

#define _release(object) \
do if (object != nil) { \
[object release]; \
object = nil; \
} while (false)

#define NSLine() NSLog(@"%s %s %d", __FILE__, __FUNCTION__, __LINE__)
#define HookLog(); \
{ \
uint32_t bt; \
__asm__("mov %0, lr": "=r"(bt)); \
NSLog(@"[%@ %s] bt=%x", [[self class] description], sel_getName(sel), bt); \
}

//*******************************************************************************************************
// Declarations (for private classes/methods)
//*******************************************************************************************************
@interface SBIcon : UIView
- (void)setShowsImages:(BOOL)images;
@end
@interface SBIcon (Firmware2x3x)
- (id)displayIdentifier;
@end
@interface SBIcon (Firmware4x)
- (id)leafIdentifier;
@end

@interface SBApplicationIcon : SBIcon @end

@interface SBIconController : NSObject @end

@interface SBIconList : UIView @end
@interface SBIconList (Firmware2x3x)
- (BOOL)firstFreeSlotX:(int *)x Y:(int *)y;
- (id)placeIcon:(id)icon atX:(int)x Y:(int)y animate:(BOOL)animate moveNow:(BOOL)now;
@end

@interface SBIconModel : NSObject
- (void)setVisibilityOfIconsWithVisibleTags:(id)visibleTags hiddenTags:(id)tags;
- (void)relayout;
@end
@interface SBIconModel (Firmware2x3x)
@property(readonly, retain) NSMutableArray *iconLists;
- (id)addEmptyIconList;
- (id)iconForDisplayIdentifier:(id)displayIdentifier;
- (id)iconListContainingIcon:(id)icon;
@end
@interface SBIconModel (Firmware4x)
- (void)addIcon:(id)icon;
- (id)leafIconForIdentifier:(id)identifier;
@end

@interface SBPlatformController : NSObject @end

@interface SBSearchView : UIView
- (BOOL)isKeyboardVisible;
@end

@interface SBSearchController : NSObject
@property(retain, nonatomic) SBSearchView *searchView;
@end
@interface SBSearchController (Firmware2x3x)
+ (id)sharedInstance;
@end

@interface SBSearchModel : NSObject // Firmware4x
- (BOOL)hasQueryString;
@end

@interface SBUIController : NSObject @end

@interface UIApplication (SpringBoard)
- (void)relaunchSpringBoard;
@end

//*******************************************************************************************************
// Globals
//*******************************************************************************************************
static NSMutableArray*	global_HiddenIconIds = nil;
static NSMutableArray*	global_HiddenSpotlightIconIds = nil;
static bool				global_Rehide = YES;
static float				global_SystemVersion = 3.0;
static SBSearchController*	global_SearchController = nil;
static bool					global_switcherShowing = NO;


#pragma mark -
#pragma mark hidden icon hooks

//*******************************************************************************************************
//                                      SBIconModel hooks
//*******************************************************************************************************
%hook SBIconModel

//*******************************************************************************************************
// 2.x renamed function
//*******************************************************************************************************
%group GSBIconModel_Firmware2x

- (BOOL)iconIsVisible:(id)iconId
{
	BOOL isVisible = %orig;
	SBApplicationIcon* icon = (SBApplicationIcon*) iconId;
	
	if(global_HiddenIconIds != nil)
	{
		if([global_HiddenIconIds containsObject:[icon displayIdentifier]])
		{
			isVisible = NO;
		}
	}
	return isVisible;	
}

%end // GSBIconModel_Firmware2x

//*******************************************************************************************************
// 3.x renamed function
//*******************************************************************************************************
%group GSBIconModel_Firmware3x

- (BOOL)isIconVisible:(id)iconId
{
	BOOL isVisible = YES;
	BOOL isShowingSearch = NO;
	SBApplicationIcon* icon = (SBApplicationIcon*) iconId;

	if(global_switcherShowing == NO)
	{
		Class SBSearchController = objc_getClass("SBSearchController");
		SBSearchController* searchController = [SBSearchController sharedInstance];
		if(searchController != nil)
		{
			SBSearchView* SearchView = [searchController searchView];
			if(SearchView != nil)
			{
				isShowingSearch = [SearchView isKeyboardVisible];
			}
		}

		if(isShowingSearch == NO)
		{
			isVisible = %orig;
			
			if(global_HiddenIconIds != nil)
			{
				//NSLog(@"Icon: %@", [icon displayIdentifier]);
				if([global_HiddenIconIds containsObject:[icon displayIdentifier]])
				{
					isVisible = NO;
				}
			}
		}
		
		// Check for hidden in spotlight key
		else if(global_HiddenSpotlightIconIds != nil)
		{
			if([global_HiddenSpotlightIconIds containsObject:[icon displayIdentifier]])
			{
				isVisible = NO;
			}
		}
	}
	
	return isVisible;
}

%end // GSBIconModel_Firmware3x

//*******************************************************************************************************
// 4.x renamed function
//*******************************************************************************************************
%group GSBIconModel_Firmware4x

- (BOOL)isIconVisible:(id)iconId
{
	// FIXME: Are the respondsToSelector: calls used in this hook necessary?

	BOOL isVisible = YES;
	BOOL isShowingSearch = NO;
	SBApplicationIcon* icon = (SBApplicationIcon*) iconId;

	if(global_switcherShowing == NO)
	{
		if(global_SystemVersion >= 4.0f)
		{
			//return %orig;
			if(global_SearchController != nil)
			{
				SBSearchView* SearchView = [global_SearchController searchView];
				if(SearchView != nil)
				{
					isShowingSearch = [SearchView isKeyboardVisible];
				}
			}
		}
		else 
		{
			// FIXME: This code is never called (?). What is its purpose?
			Class SBSearchModel = objc_getClass("SBSearchModel");
			SBSearchModel* searchModel = [SBSearchModel sharedInstance];
			if(searchModel != nil)
			{
				isShowingSearch = [searchModel hasQueryString];
			}
		}

		if(isShowingSearch == NO)
		{
			isVisible = %orig;
			
			if(global_HiddenIconIds != nil)
			{
				//NSLog(@"LibHide: %@", [icon leafIdentifier]);
				if([icon respondsToSelector:@selector(leafIdentifier)] &&  
				   [global_HiddenIconIds containsObject:[icon leafIdentifier]])
				{
					isVisible = NO;
				}
			}
		}
		
		// Check for hidden in spotlight key
		else if(global_HiddenSpotlightIconIds != nil)
		{
			if([icon respondsToSelector:@selector(leafIdentifier)] &&
			   [global_HiddenSpotlightIconIds containsObject:[icon leafIdentifier]])
			{
				isVisible = NO;
			}
		}
	}
	
	if([icon respondsToSelector:@selector(leafIdentifier)])
	{
		NSString* leafId = [icon leafIdentifier];
		if([leafId isEqualToString: @"com.apple.AdSheet"] || 
			[leafId isEqualToString: @"com.apple.DemoApp"] ||
			[leafId isEqualToString: @"com.apple.iphoneos.iPodOut"] ||
			[leafId isEqualToString: @"com.apple.TrustMe"] ||
			[leafId isEqualToString: @"com.apple.webapp"] ||
			[leafId isEqualToString: @"com.apple.WebSheet"] ||
			[leafId isEqualToString: @"com.apple.nike"] )
		{
			isVisible = %orig;
		}
	}
	
	return isVisible;
}

%end // GSBIconModel_Firmware4x

%end // SBIconModel

//*******************************************************************************************************
//                                   SBSearchController hooks
//*******************************************************************************************************
%hook SBSearchController

//*******************************************************************************************************
//*******************************************************************************************************
- (id)init
{
	id newSearchController = %orig;
	
	global_SearchController = newSearchController;
	
	return newSearchController;
}

%end // SBSearchController

%group GHiddenIcons

//*******************************************************************************************************
//                                     SBUIController hooks
//*******************************************************************************************************
%hook SBUIController

//*******************************************************************************************************
//*******************************************************************************************************
- (void)_toggleSwitcher
{
	global_switcherShowing = YES;
	%orig;
}

//*******************************************************************************************************
//*******************************************************************************************************
- (void)_dismissSwitcher:(double)switcher
{
	%orig;
	global_switcherShowing = NO;
}

%end // SBUIController


#pragma mark -
#pragma mark always-used hooks

//*******************************************************************************************************
//                                  SBPlatformController hooks
//*******************************************************************************************************
%hook SBPlatformController

//*******************************************************************************************************
// setInfo - Called for capabilities of app
//*******************************************************************************************************
- (void)setInfo:(NSMutableArray *)arrayOfApps forCapability:(NSString *)Capability
{
	if(Capability != nil && [Capability isEqualToString:@"application-display-identifiers"])
	{
		//This assumes arrayOfApps is mutable and not just an NSArray. 
		if(![arrayOfApps respondsToSelector:@selector(addObjectsFromArray:)])
		{
			[arrayOfApps addObjectsFromArray:global_HiddenIconIds];
		}
		
		// In case the array is not mutable.
		else
		{
			NSMutableArray* mutableArray = [NSMutableArray arrayWithArray:arrayOfApps];
			[mutableArray addObjectsFromArray:global_HiddenIconIds];
			arrayOfApps = mutableArray;
		}
	}
	
	%orig;
}

%end // SBPlatformController

%end // GHiddenIcons

#pragma mark -
#pragma mark non-hooks

//*******************************************************************************************************
//                                        Non-hooks
//*******************************************************************************************************

//*******************************************************************************************************
// LoadHiddenIconList
//*******************************************************************************************************
int LoadHiddenIconList()
{
	int HiddenIcons = 0;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:@HIDLIBPATH])
	{
		NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@HIDLIBPATH];

		if(global_HiddenIconIds != nil)
		{
			[global_HiddenIconIds release];
		}
		
		global_HiddenIconIds = [[NSMutableArray alloc] initWithArray:[Dict objectForKey:@"Hidden"]];
		if(global_HiddenIconIds != nil)
		{
			if([global_HiddenIconIds containsObject:@"com.apple.mobileipod"])
			{
				[global_HiddenIconIds removeObject:@"com.apple.mobileipod"];
				[global_HiddenIconIds addObject:@"com.apple.mobileipod-MediaPlayer"];
			}
			
			HiddenIcons = [global_HiddenIconIds count];
		}
		
		// This list is for icons to hide from spotlight. 
		global_HiddenSpotlightIconIds = [[NSMutableArray alloc] initWithArray:[Dict objectForKey:@"Spotlight"]];
	}
	
	NSLog(@"LibHide: Returning %d icons hidden", HiddenIcons);
	
	return HiddenIcons;
}

//*******************************************************************************************************
//*******************************************************************************************************
void* MSHookIvar(id self, const char *unitName) 
{
    Ivar ivar =  class_getInstanceVariable(object_getClass(self), unitName);
    void *pointer = (ivar == NULL ? NULL : (char*)(self) + ivar_getOffset(ivar));
    return pointer;
}

//*******************************************************************************************************
// IconHide_HiddenIconsChanged - Runs when the nofify_post(com.libhide.hiddeniconschanged) is called.
//*******************************************************************************************************
static void IconHide_HiddenIconsChanged(CFNotificationCenterRef center,
											  void *observer,
											  CFStringRef name,
											  const void *object,
											  CFDictionaryRef info
											  )
{
	if([[[UIDevice currentDevice] systemVersion] hasPrefix:@"2."])
	{
		UIApplication* theApp = [UIApplication sharedApplication];
		if([theApp respondsToSelector:@selector(relaunchSpringBoard)])
		{
			[theApp relaunchSpringBoard];
		}
	}
	
	else if([[[UIDevice currentDevice] systemVersion] hasPrefix:@"5."])
	{
		LoadHiddenIconList();
		
		Class SBIconModel = objc_getClass("SBIconModel");
		SBIconModel* iconModel = (SBIconModel*)[SBIconModel sharedInstance];
		NSSet** _visibleIconTags = (NSSet**)MSHookIvar(iconModel, "_visibleIconTags");
		NSSet** _hiddenIconTags  = (NSSet**)MSHookIvar(iconModel, "_hiddenIconTags");
		if(*_visibleIconTags != NULL && *_hiddenIconTags != NULL &&
		    _visibleIconTags != NULL && _hiddenIconTags!=NULL)
		{
			global_Rehide = YES;
			NSSet* visibleIconTags = [NSSet setWithSet:*_visibleIconTags];
			NSSet* hiddenIconTags = [NSSet setWithSet:*_hiddenIconTags];
			[iconModel setVisibilityOfIconsWithVisibleTags:visibleIconTags  hiddenTags:hiddenIconTags];
			[iconModel relayout];
		}
	}

	else 
	{
		LoadHiddenIconList();
		
		Class SBIconModel = objc_getClass("SBIconModel");
		SBIconModel* iconModel = (SBIconModel*)[SBIconModel sharedInstance];
		NSSet** _visibleIconTags = (NSSet**)MSHookIvar(iconModel, "_visibleIconTags");
		NSSet** _hiddenIconTags  = (NSSet**)MSHookIvar(iconModel, "_hiddenIconTags");
		if(*_visibleIconTags != NULL && *_hiddenIconTags != NULL)
		{
			global_Rehide = YES;
			NSArray* visibleIconTags = [*_visibleIconTags allObjects];
			NSArray* hiddenIconTags = [*_hiddenIconTags allObjects];
			[iconModel setVisibilityOfIconsWithVisibleTags:visibleIconTags  hiddenTags:hiddenIconTags];
		}
	}

}

//*******************************************************************************************************
//*******************************************************************************************************
float getSystemVersion()
{
	float Version = 4.0;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/System/Library/CoreServices/SystemVersion.plist"])
	{
		NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		
		NSLog(@"LibHide: Querying system version");
		Version = [[Dict objectForKey:@"ProductVersion"] floatValue];
	}
	
	NSLog(@"LibHide: returning version %f", Version);
	
	return Version;
}

#pragma mark -
#pragma mark dylib initializer

//*******************************************************************************************************
// dylib initializer or entry point.
//*******************************************************************************************************
__attribute__((constructor)) static void init()
{	
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	
	NSLog(@"LibHide: v" IH_VERSION " initializer");
	
	global_SystemVersion = getSystemVersion();
	
	//Check open application and create hooks here:
	NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
	if([identifier isEqualToString:@"com.apple.springboard"])
	{
		if(LoadHiddenIconList() != 0)
		{
			%init(GHiddenIcons);

			if(SYS_VER_2(global_SystemVersion))
			{
				%init(GSBIconModel_Firmware2x);
			}
			else if(SYS_VER_3(global_SystemVersion))
			{
				%init(GSBIconModel_Firmware3x);
			}
			else
			{
				%init(GSBIconModel_Firmware4x);
			}
		}

		// Initialize remaining (non-grouped) hooks
		%init;
		
		// Set the rehide flag for setVisibilityOfIcons* function.
		global_Rehide = YES;
	}

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
										 NULL, 
										 &IconHide_HiddenIconsChanged, 
										 (CFStringRef) @"com.libhide.hiddeniconschanged", 
										 NULL, 
										 CFNotificationSuspensionBehaviorDeliverImmediately);	
	
	NSLog(@"LibHide: initializer completed and you're not in safe mode!");

	[pool release];
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 noexpandtab textwidth=80 ff=unix: */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import "main.h"
#import <sys/utsname.h>      /* for uname structure          */
#include <sys/stat.h>
#include <unistd.h>
#include <notify.h>

//*************************************************************************************************
// IsPlistFileBinary - determines of the plist file is in binary format or not
//*************************************************************************************************
BOOL IsPlistFileBinary(char* Title)
{
	BOOL Binary = YES;
	char t1;
	char t2;
	char t3;
	
	FILE* fp = fopen(Title, "r");
	if(fp != NULL)
	{
		t1 = fgetc(fp);
		t2 = fgetc(fp);
		t3 = fgetc(fp);
		
		if(t1 == '<' && t2 == '?' && t3 == 'x')
		{
			Binary = NO;
		}
		fclose(fp);
	}
	
	return Binary;
}

//*************************************************************************************************
// IsPlistBinary - Determines if the plist is binary or xml. 
// Returns YES for binary, NO for XML
//*************************************************************************************************
BOOL IsPlistFileBinaryNS(NSString* Path)
{
	return IsPlistFileBinary((char*)[Path UTF8String]);
}

//*************************************************************************************************
// HideLibIsTouch - Gets the OS version and optionally the platform
//*************************************************************************************************
BOOL HideLibIsTouch()
{
	static BOOL Touch = NO;
		
	struct utsname  UtsName;
	uname(&UtsName);

	if(strstr(UtsName.machine, "iPod") != NULL)
	{
		Touch = YES;
	}
	else
	{
		Touch = NO;
	}

	return Touch;
}

//*************************************************************************************************
// Respring - Restarts springboard.
//*************************************************************************************************
void Respring()
{
	notify_post("com.apple.language.changed");   
}

//*************************************************************************************************
// ConvertPlistToXml - Converts the plist file to XML format
//*************************************************************************************************
void ConvertPlistToXml(NSString* Path)
{
	// Convert the plist by opening it, reading it, and saving it.
	NSMutableDictionary* List = [[NSMutableDictionary alloc] initWithContentsOfFile:Path];
	[List writeToFile:Path atomically: YES];
	[List release];
}

//*************************************************************************************************
// UnHideSpecialIcon - UnHides the camera or photos icons.
//*************************************************************************************************
BOOL UnHideSpecialIcon(NSString* Path, BOOL UpdateMaster)
{
	FILE* fp = NULL;
	FILE* Out = NULL;
	char Temp[512];
	int i = 0;
	long PrevLine = 0;
	int UIRoleDisplayCount = 0;
	int UIRoleFoundCount = 0;
	BOOL Hidden = NO;
	BOOL Changed = NO;
	BOOL Photos = NO;
	BOOL IsTouch = NO;
	
	if([Path isEqualToString:@"Photos.app"] == YES)
	{
		Photos = YES;
	}
	
	// Check for camera and touch. Camera isnt supported on the touch.
	IsTouch = HideLibIsTouch();
	if(Photos == NO && IsTouch == YES)
	{
		return NO;
	}
	
	// UIRoleDisplayCount occurs 3 times in the file and depending if its touch, photos, or camera will be in 3 locations. We are assuming the file is always in the same order
	// and just counting instances to know where to add the hidden tags.
	if(Photos == NO)
	{
		UIRoleDisplayCount = 2;
	}
	else if(IsTouch == YES)
	{
		UIRoleDisplayCount = 3;
	}
	else
	{
		UIRoleDisplayCount = 1;
	}
	
	NSString* InfoPlist = [[NSString alloc] initWithString:@"/Applications/MobileSlideShow.app/Info.plist"];
	NSString* InfoPlistOut = [[NSString alloc] initWithFormat:@"/Applications/MobileSlideShow.app/Info.plist_Info.Out", Path];
	
	if(IsPlistFileBinaryNS(InfoPlist) == YES)
	{
		NSLog(@"HideIcon: Plist is still in binary, converting to XML for %@\n", Path);
		ConvertPlistToXml(InfoPlist);
	}
	
	fp = fopen([InfoPlist UTF8String], "r");
	if(fp != NULL)
	{
		// Find the line with >hidden<
		while(!feof(fp))
		{
			if(fgets(Temp, 511, fp) == NULL) break;
			if(strstr(Temp, "</plist>") != NULL) break;
			
			// Scan for the location of the "UIRoleDisplayName"
			if(strstr(Temp, ">UIRoleDisplayName<") != NULL)
			{
				UIRoleFoundCount++;
				if(UIRoleFoundCount == UIRoleDisplayCount)
				{
					// Once the role is found, look to see if it is already hidden.
					if(fgets(Temp, 511, fp) == NULL) break;
					if(fgets(Temp, 511, fp) == NULL) break;
					if(fgets(Temp, 511, fp) == NULL) break;
					if(fgets(Temp, 511, fp) == NULL) break;
					if(strstr(Temp, ">hidden<") != NULL)
					{
						Hidden = YES;
					}
					break;
				}
			}
			
			PrevLine++;
		}
		rewind(fp);

		if(Hidden == YES)
		{
			Out = fopen([InfoPlistOut UTF8String], "w");
			if(Out != NULL)
			{
				NSLog(@"Opened %@ for writing, PrevLine = %d\n", InfoPlistOut, PrevLine);
				for(i = 0; i < PrevLine + 2; i++)
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}

				// Delete the 4 lines containing the "hidden" key.
				NSLog(@"Deleting hidden section\n");
				fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				
				while(!feof(fp))
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}
				fclose(Out);
			}
		}
		fclose(fp);
		
		if(Hidden == YES)
		{
			remove([InfoPlist UTF8String]);
			rename([InfoPlistOut UTF8String], [InfoPlist UTF8String]);
			Changed = YES;
		}
	}
	
	[InfoPlist release];
	[InfoPlistOut release];
	
	return Changed;
}

//*************************************************************************************************
// GetDisplayNameFromPath - Returns the name of the icon file used in the info.plist passed in.
//*************************************************************************************************
NSString* GetDisplayNameFromPath(NSString* PlistPath)
{
	NSString* IconFile = nil;
	NSString* IconFileTemp = nil;
	
	NSMutableDictionary* List = [[NSMutableDictionary alloc] initWithContentsOfFile:PlistPath];
	
	if(List)
	{
		// Get the bundle ID
		IconFileTemp = [List objectForKey:@"CFBundleDisplayName"];
		if(IconFileTemp != nil)
		{
			IconFile = [[NSString alloc] initWithString:IconFileTemp];
		}
		[List release];
	}
	
	return IconFile;
}

//*************************************************************************************************
// GetIconFromePath - Returns the icon out of the plist passed in.
// Note: this function is misnamed but already used in bossprefs so cant be removed for now.
//*************************************************************************************************
NSString* GetIconFromPath(NSString* PlistPath)
{
	return GetIconFromPlist(PlistPath);
}

//*************************************************************************************************
// GetIconFromPath - Returns the name of the icon file used in the info.plist passed in.
//*************************************************************************************************
NSString* GetIconFromPlist(NSString* PlistPath)
{
	NSString* IconFile = nil;
	NSString* IconFileTemp = nil;
	
	NSMutableDictionary* List = [[NSMutableDictionary alloc] initWithContentsOfFile:PlistPath];
	
	if(List)
	{
		// Get the bundle ID
		IconFileTemp = [List objectForKey:@"CFBundleIconFile"];
		if(IconFileTemp != nil)
		{
			IconFile = [[NSString alloc] initWithString:IconFileTemp];
		}
		[List release];
	}
	
	return IconFile;
}

//*************************************************************************************************
// GetIconFromFilePath - Returns the name of the icon file used in the info.plist passed in.
//                  
// Note: For exception cases, camera and photos, pass in just "/Applications/Photos.app" or 
//       "/Applications/Camera.app" for the path.
//*************************************************************************************************
NSString* GetIconFromFilePath(NSString* ApplicationPath)
{
	NSString*		IconString	= nil;
	NSString*		IconFile	= nil;
	NSFileManager*	FileManager = [NSFileManager defaultManager];
	
	if([ApplicationPath isEqualToString:@"/Applications/Camera.app"] == YES)
	{
		IconString = [[NSString alloc] initWithString: @"/Applications/MobileSlideShow.app/icon-Camera.png"];
	}
	else if([ApplicationPath isEqualToString:@"/Applications/Photos.app"] == YES)
	{
		IconString = [[NSString alloc] initWithString:@"/Applications/MobileSlideShow.app/icon-Photos.png"];
	}
	else if([FileManager fileExistsAtPath: [NSString stringWithFormat:@"%@/icon.png", ApplicationPath]])
	{
		IconString = [[NSString alloc] initWithFormat:@"%@/icon.png", ApplicationPath];
	}
	else if([FileManager fileExistsAtPath: [NSString stringWithFormat:@"%@/Icon.png", ApplicationPath]])
	{
		IconString = [[NSString alloc] initWithFormat:@"%@/Icon.png", ApplicationPath];
	}
	else
	{
		IconFile = GetIconFromPlist([NSString stringWithFormat:@"%@/Info.plist", ApplicationPath]);
		if(IconFile != nil)
		{
			if([[IconFile substringFromIndex:([IconFile length] - 4)] isEqualToString:@".png"] == NO)
			{
				IconString = [[NSString alloc] initWithFormat:@"%@/%@.png", ApplicationPath, IconFile];
			}
			else
			{
				IconString = [[NSString alloc] initWithFormat:@"%@/%@", ApplicationPath, IconFile];
			}
		}
		
		if(IconString != nil)
		{
			if([FileManager fileExistsAtPath: IconString] == NO)
			{
				[IconString release];
				IconString = nil;
			}
		}
	}
	
	return IconString;
}

//*************************************************************************************************
// GetPathFromAppFolderName - Gets the path to the file from the folder name.
//
// Note: Camera.app and Photos.app just return /Applications/Cameras.app / /Applications/Photos.app
//*************************************************************************************************
NSString* GetPathFromAppFolderName(NSString* FolderName)
{
	NSString*		Path		= nil;
	NSFileManager*	FileManager	= [NSFileManager defaultManager];
	NSString*		TempFolder  = nil;
	
	if([FolderName isEqualToString:@"Camera.app"] == YES)
	{
		Path = [[NSString alloc] initWithString:@"/Applications/Camera.app"];
	}
	else if([FolderName isEqualToString:@"Photos.app"] == YES)
	{
		Path = [[NSString alloc] initWithString:@"/Applications/Photos.app"];
	}
	else
	{
		// Check /Applications for it
		TempFolder = [NSString stringWithFormat:@"/Applications/%@", FolderName];
		if([FileManager fileExistsAtPath: TempFolder] == YES)
		{
			Path = [[NSString alloc] initWithString:TempFolder];
		}

		// Check AppStore apps for it
		if(Path == nil)
		{
			NSArray* AppDirs = [[NSArray alloc] initWithArray:[FileManager directoryContentsAtPath:@"/var/mobile/Applications"]];
			int		 i		 = 0;
			
			for(i = 0; i < [AppDirs count]; i++)
			{
				TempFolder = [NSString stringWithFormat:@"/var/mobile/Applications/%@/%@", [AppDirs objectAtIndex:i], FolderName];
				if([FileManager fileExistsAtPath: TempFolder] == YES)
				{
					Path = [[NSString alloc] initWithString:TempFolder];
					break;
				}
			}
			
			[AppDirs release];
		}
	}
	
	return Path;
}

//*************************************************************************************************
// GetPathFromBundleId - Takes the BundleId passed in and returns the path to the bundle.
//
// Note: For Camera and Photos, it returns "/Applications/Camera.app" / "/Applications/Photos.app"
// Note: Function never tested
//*************************************************************************************************
NSString* GetPathFromBundleId(NSString* BundleId)
{
	NSString* Path = nil;
	
	// Exception case - Photos.
	if([BundleId isEqualToString:@"com.apple.mobileslideshow-Photos"])
	{
		Path = [[NSString alloc] initWithString:@"/Applications/Photos.app"];
	}
	
	// Exception case - Camera
	else if([BundleId isEqualToString:@"com.apple.mobileslideshow-Camera"])
	{
		Path = [[NSString alloc] initWithString:@"/Applications/Camera.app"];
	}
	
	// Scan each apps folder, take the path and get the bundle ID and see if it equals the bundle we need.
	else
	{
		NSFileManager*	FileManager		= [NSFileManager defaultManager];
		NSArray*		AppDirs			= nil;
		NSArray*		AppStoreApps	= nil;
		NSString*		AppDirTitle		= nil;
		NSString*		PrefixDir		= nil;
		NSString*		AppPath			= nil;
		NSString*		ThisBundle		= nil;
		int				i				= 0;
		int				j				= 0;
		
		// First scan /Applications
		AppDirs = [[NSArray alloc] initWithArray:[FileManager directoryContentsAtPath:@"/Applications"]];
		for(i = 0; i < [AppDirs count]; i++)
		{
			AppDirTitle = [NSString stringWithString:[AppDirs objectAtIndex:i]];
			NSLog(@"AppDirTitle = %@\n", AppDirTitle);
			
			// Filter some garbage such as . folders and folders without .app (none of these should exist but sometimes do)
			if(strstr([AppDirTitle UTF8String], ".app") == NULL) continue;
			if(([AppDirTitle UTF8String])[0] == '.') continue;
			
			AppPath = [NSString stringWithFormat:@"/Applications/%@/Info.plist", AppDirTitle];
			ThisBundle = GetBundleFromPath(AppPath);
			if(ThisBundle != nil)
			{
				// Found it! Store it off and break the search loop.
				if([ThisBundle isEqualToString: BundleId] == YES)
				{
					Path = [[NSString alloc] initWithString: AppPath];
					[ThisBundle release];
					break;
				}
				[ThisBundle release];
			}
			
		}
		
		NSLog(@"Freeing AppDirs array for /Applications\n");
		// Free the array
		for(i = 0; i < [AppDirs count]; i++)
		{
			[[AppDirs objectAtIndex:i] release];
		}
		[AppDirs release];
		
		// If we're still here, time to scan AppStore folders.
		if(Path != nil)
		{
			NSString*	FullAppPath = nil;
			BOOL		AppExists	= NO;
			
			AppDirs = [[NSArray alloc] initWithArray:[FileManager directoryContentsAtPath:@"/var/mobile/Applications"]];
			for(i = 0; i < [AppDirs count]; i++)
			{
				PrefixDir = [NSString stringWithFormat:@"/var/mobile/Applications/%@", [AppDirs objectAtIndex: i]];
				NSLog(@"PrefixDir = %@\n", PrefixDir);
				AppStoreApps = [[NSArray alloc] initWithArray:[FileManager directoryContentsAtPath: PrefixDir]];
				AppExists = NO;
				for(j = 0; j < [AppStoreApps count]; j++)
				{
					AppDirTitle = [NSString stringWithFormat: [AppStoreApps objectAtIndex: j]];
					NSLog(@"AppDirTitle = %@\n", AppDirTitle);
					
					// Filter garbage
					if(strstr([AppDirTitle UTF8String], ".app") == NULL) continue;
					if(([AppDirTitle UTF8String])[0] == '.') continue;
					AppExists = YES;
					break;
				}
				
				NSLog(@"Freeing AppStoreApps array iteration %d\n", i);
				for(j = 0; j < [AppStoreApps count]; j++)
				{
					[[AppStoreApps objectAtIndex:i] release];
				}
				[AppStoreApps release];
				
				if(AppExists == NO) continue;
				
				FullAppPath = [NSString stringWithFormat:@"%@/%@/Info.plist", PrefixDir, AppDirTitle];
				NSLog(@"FullAppPath = %@\n", FullAppPath);
				
				ThisBundle = GetBundleFromPath(FullAppPath);
				if(ThisBundle != nil)
				{
					// Found it! Store it off and break the search loop.
					if([ThisBundle isEqualToString: BundleId] == YES)
					{
						Path = [[NSString alloc] initWithString: AppPath];
						[ThisBundle release];
						break;
					}
					[ThisBundle release];
				}
			}

			NSLog(@"Freeing AppDirs array for /var/mobile/Applications\n");
			// Free the array
			for(i = 0; i < [AppDirs count]; i++)
			{
				[[AppDirs objectAtIndex:i] release];
			}
			[AppDirs release];
			
		}
	}
	
	return Path;
}

//*************************************************************************************************
// GetBundleFromPath - Returns an allocated NSString that contains the bundle from the path passed in. The returned string should
//			       be freed later with release.
//*************************************************************************************************
NSString* GetBundleFromPath(NSString* PlistPath)
{
	NSString* BundleId = nil;
	
	if([PlistPath isEqualToString:@"/Applications/Photos.app/Info.plist"])
	{
		BundleId = [[NSString alloc] initWithString:@"com.apple.mobileslideshow-Photos"];
	}
	else if([PlistPath isEqualToString:@"/Applications/Camera.app/Info.plist"])
	{
		BundleId = [[NSString alloc] initWithString:@"com.apple.mobileslideshow-Camera"];
	}
	else
	{
		NSMutableDictionary* List = [[NSMutableDictionary alloc] initWithContentsOfFile:PlistPath];
		
		if(List)
		{
			// Get the bundle ID
			BundleId = [[NSString alloc] initWithString:[List objectForKey:@"CFBundleIdentifier"]];
			[List release];
		}
	}
	
	return BundleId;
}

BOOL UseRestrictionsForHide(NSString* Path)
{
	BOOL Restrictions = YES;
	
	if([Path isEqualToString:@"/Applications/MobileSafari.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileMusicPlayer.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/YouTube.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileStore.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileSMS.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/BossPrefs.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Maps.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileAddressBook.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileCal.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileMail.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileNotes.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobilePhone.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileTimer.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Preferences.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MobileSlideShow.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Stocks.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Weather.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Cydia.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Installer.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/FileViewer.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/Calendar.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/iRealSMS.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/MySMS.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/biteSMS.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/WinterBoard.app/Info.plist"] ||
	   [Path isEqualToString:@"/Applications/AppStore.app/Info.plist"])
	{
		Restrictions = NO;
	}
	
	return Restrictions;
}

//*************************************************************************************************
// IsIconHiddenCharPtr - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL IsIconHiddenCharPtr(char* Path)
{
	NSString* Temp = [NSString stringWithUTF8String: Path];
	return IsIconHidden(Temp);
}

//*************************************************************************************************
// IsIconHiddenDisplayId - determines if icon is hidden by display ID. 
//*************************************************************************************************
BOOL IsIconHiddenDisplayId(NSString* BundleId)
{
	BOOL Hidden = NO;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:@HIDLIBPATH])
	{
		NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@HIDLIBPATH];
		NSMutableArray* HiddenIconIds = [Dict objectForKey:@"Hidden"];
		if(HiddenIconIds != nil && [HiddenIconIds count] > 0)
		{
			for(int i = 0; i < [HiddenIconIds count]; i++)
			{
				if([BundleId isEqualToString:[HiddenIconIds objectAtIndex:i]])
				{
					Hidden = YES;
					break;
				}
			}
		}
	}
	
	return Hidden;
}

//*************************************************************************************************
// IsIconHidden - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL IsIconHidden(NSString* Path)
{
	BOOL Hidden = NO;
	NSString* BundleId = GetBundleFromPath(Path);
	Hidden = IsIconHiddenDisplayId(BundleId);
	if(Hidden == NO) Hidden = IsIconHiddenOld(Path);
	
	return Hidden;
}

//*************************************************************************************************
// IsIconHidden - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL IsIconHiddenOld(NSString* Path)
{
	NSString* CurrentPlist;
	BOOL Hidden = NO;
	BOOL HiddenOld = NO;
	
	NSLog(@"Checking if %@ is hidden\n", Path);
	// Get the bundle ID
	if(UseRestrictionsForHide(Path) == NO)
	{
		HiddenOld = IsIconHiddenInfoPlist(Path);
	}
	if(HiddenOld == YES)
	{
		return YES;
	}
	
	NSString* BundleId = GetBundleFromPath(Path);

	if(BundleId != nil)
	{
		NSMutableDictionary* List = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
		if(List)
		{
			NSMutableArray* Packages = [[NSMutableArray alloc] initWithArray:[List objectForKey:@"SBParentalControlsApplications"]];
			if(Packages)
			{
				// Make sure the package is not already hidden.
				int Count = [Packages count];
				for(int i = 0; i < Count; i ++)
				{
					CurrentPlist = [Packages objectAtIndex:i];
					if([CurrentPlist isEqualToString:BundleId])
					{
						Hidden = YES;
						break;
					}
				}
				[Packages release];
			}
			[List release];
		}
		[BundleId release];
	}
	
	return Hidden;
}

//*************************************************************************************************
// IsIconHidden - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL IsIconHiddenInfoPlist(NSString* PlistPath)
{
	char Temp[512];
	BOOL Hidden = NO;
	
	ConvertPlistToXml(PlistPath);
	
	FILE* fp = fopen([PlistPath UTF8String], "r");
	if(fp != NULL)
	{
		// Find the line with >hidden<
		while(!feof(fp))
		{
			if(fgets(Temp, 511, fp) == NULL) break;
			if(strstr(Temp, ">hidden<") != NULL)
			{
				Hidden = YES;
			}
			if(strstr(Temp, "</plist>") != NULL) break;
		}
		fclose(fp);
	}
	return Hidden;
}

//*************************************************************************************************
// HideIcon - Hides the icon at the path passed in.
//*************************************************************************************************
BOOL HideIconInPlist(NSString* Path)
{
	FILE* fp = NULL;
	FILE* Out = NULL;
	char Temp[512];
	int i = 0;
	long PrevLine = 0;
	BOOL Hidden = NO;
	BOOL Changed = NO;
	
	NSString* InfoPlist = [[NSString alloc] initWithString:Path];
	NSString* InfoPlistOut = [[NSString alloc] initWithFormat:@"%@_Info.Out", Path];
	
	ConvertPlistToXml(InfoPlist);
	
	fp = fopen([InfoPlist UTF8String], "r");
	if(fp != NULL)
	{
		// Find the line with >hidden<
		while(!feof(fp))
		{
			if(fgets(Temp, 511, fp) == NULL) break;
			if(strstr(Temp, ">hidden<") != NULL)
			{
				Hidden = YES;
			}
			if(strstr(Temp, "</plist>") != NULL) break;
			PrevLine++;
		}
		rewind(fp);

		if(Hidden == NO)
		{
			Out = fopen([InfoPlistOut UTF8String], "w");
			if(Out != NULL)
			{
				NSLog(@"Opened %@ for writing, PrevLine = %d\n", InfoPlistOut, PrevLine);
				for(i = 0; i < PrevLine - 1; i++)
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}

				NSLog(@"Writing hidden section\n");

				// Write the 4 lines with array, hidden, /array
				fprintf(Out, "\t<key>SBAppTags</key>\n");
				fprintf(Out, "\t<array>\n");
				fprintf(Out, "\t\t<string>hidden</string>\n");
				fprintf(Out, "\t</array>\n");
				
				while(!feof(fp))
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}
				fclose(Out);
			}
		}
		fclose(fp);
		
		if(Hidden == NO)
		{
			remove([InfoPlist UTF8String]);
			rename([InfoPlistOut UTF8String], [InfoPlist UTF8String]);
			Changed = YES;
		}
	}
	
	[InfoPlist release];
	[InfoPlistOut release];
	
	return Changed;
}

//*************************************************************************************************
// HideIconCharPtr - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL HideIconCharPtr(char* Path)
{
	NSString* Temp = [NSString stringWithUTF8String: Path];
	return HideIcon(Temp);
}

//*************************************************************************************************
// HideIconViaDisplayId - Hides the icon using the display ID passed in.
//*************************************************************************************************
BOOL HideIconViaDisplayId(NSString* BundleId)
{
	BOOL DeletedSomething = NO;
	
	if(IsIconHiddenDisplayId(BundleId) == NO)
	{
		NSMutableArray* HiddenIconIds = nil;
		NSMutableDictionary* Dict = nil;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:@HIDLIBPATH])
		{
			NSLog(@"LibHide: plist exists already\n");
			Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@HIDLIBPATH];
			HiddenIconIds = [Dict objectForKey:@"Hidden"];
		}
		else
		{
			NSLog(@"LibHide: plist does not exist, making folder at /var/mobile/Library/LibHide\n");
			mkdir("/var/mobile/Library/LibHide", 0777);
			Dict = [NSMutableDictionary dictionaryWithCapacity:1];
			HiddenIconIds = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];
		}
		
		if(HiddenIconIds != nil)
		{
			[HiddenIconIds addObject:BundleId];
			[Dict setObject: HiddenIconIds forKey:@"Hidden"];
			[Dict writeToFile:@HIDLIBPATH atomically:YES];
			chmod(HIDLIBPATH, 0666);
			DeletedSomething = YES;
		}
	}
	
	return DeletedSomething;
}

//*************************************************************************************************
// HideIcon - Hides the icon at the path passed in.
//*************************************************************************************************
BOOL HideIcon(NSString* PlistPath)
{
	BOOL DeletedSomething = NO;
	
	NSLog(@"LibHide: Hiding %@\n", PlistPath);
	NSString* BundleId = GetBundleFromPath(PlistPath);
	DeletedSomething = HideIconViaDisplayId(BundleId);
	
	return DeletedSomething;
}

//*************************************************************************************************
// UnHideIconCharPtr - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL UnHideIconCharPtr(char* Path)
{
	NSString* Temp = [NSString stringWithUTF8String: Path];
	return UnHideIcon(Temp);
}


//*************************************************************************************************
// UnHideIcon - Removes a hidden icon from the plist. Returns TRUE  if something was done, FALSE ir not.
//*************************************************************************************************
BOOL UnHideIconViaDisplayId(NSString* BundleId)
{
	BOOL DeletedSomething = NO;
	
	if(IsIconHiddenDisplayId(BundleId) == YES)
	{
		if([[NSFileManager defaultManager] fileExistsAtPath:@HIDLIBPATH])
		{
			NSLog(@"LibHide: Deleting from dylib dictionary list\n");
			NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@HIDLIBPATH];
			NSMutableArray* HiddenIconIds = [Dict objectForKey:@"Hidden"];
			int Count = 0;
			
			if(HiddenIconIds != nil)
			{
				NSLog(@"LibHide: Deleting from dylib dictionary list\n");
				Count = [HiddenIconIds count];
				[HiddenIconIds removeObject:BundleId];
				[Dict setObject: HiddenIconIds forKey:@"Hidden"];
				[Dict writeToFile:@HIDLIBPATH atomically:YES];
				chmod(HIDLIBPATH, 0666);

				if([HiddenIconIds count] != Count)
				{
					DeletedSomething = YES;
				}
			}
		}
	}
	
					
#if 0
					// Convert to Binary
					NSString* error;
					NSData* plistData = [NSPropertyListSerialization dataFromPropertyList:List
																	 format:NSPropertyListBinaryFormat_v1_0
																	 errorDescription:&error];
					[plistData writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
#endif	
	
	return DeletedSomething;
}

//*************************************************************************************************
// UnHideIcon - Removes a hidden icon from the plist. Returns TRUE  if something was done, FALSE ir not.
//*************************************************************************************************
BOOL UnHideIcon(NSString* PlistPath)
{
	NSString* BundleId = GetBundleFromPath(PlistPath);
	BOOL DeletedSomething = UnHideIconViaDisplayId(BundleId);
	
	if(DeletedSomething == NO)
	{
		NSLog(@"LibHide: Did not find something to delete in dylib dictionary, trying old method.\n");
		DeletedSomething = UnHideIconOld(PlistPath);
	}
	
	return DeletedSomething;
}

//*************************************************************************************************
// UnHideIconOld - Removes a hidden icon from the plist. Returns TRUE  if something was done, FALSE ir not.
//*************************************************************************************************
BOOL UnHideIconOld(NSString* Path)
{
	NSString* CurrentPlist;
	int Count = 0;
	int i = 0;
	BOOL SomethingDone = NO;
	BOOL SomethingDonePlist = NO;
	
	if(IsIconHidden(Path) == YES)
	{
		NSString* BundleId = GetBundleFromPath(Path);
		if(BundleId != nil)
		{
			NSMutableDictionary* NList = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
			if(NList)
			{
				NSMutableArray* Packages = [[NSMutableArray alloc] initWithArray:[NList objectForKey:@"SBParentalControlsApplications"]];
				if(Packages)
				{
					// Make sure the package is not already hidden.
					Count = [Packages count];
					for(i = 0; i < Count; i ++)
					{
						CurrentPlist = [Packages objectAtIndex:i];
						if([CurrentPlist isEqualToString:BundleId])
						{
							NSLog(@"Found entry, removing it.\n");
							[Packages removeObjectAtIndex:i];
							SomethingDone = YES;
							break;
						}
					}
					
					if(SomethingDone == YES)
					{
						[NList setObject:Packages forKey:@"SBParentalControlsApplications"];
#if 0
					// Convert to Binary
					NSString* error;
					NSData* plistData = [NSPropertyListSerialization dataFromPropertyList:List
																	 format:NSPropertyListBinaryFormat_v1_0
																	 errorDescription:&error];
					[plistData writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
#endif												 
						[NList writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
						chmod("/var/mobile/Library/Preferences/com.apple.springboard.plist", 0666);
					}
					[Packages release];
				}
				else
				{
					NSLog(@"Packages = nil\n");
				}
				[NList release];
			}
			[BundleId release];
		}
	}
	
	// These apps are unusable if hidden in springboard cause they will be restricted.
	if(UseRestrictionsForHide(Path) == NO)
	{
		SomethingDonePlist = UnHideIconOlder(Path);
	}
	
	if(SomethingDone == YES || SomethingDonePlist == YES)
	{
		SomethingDone = YES;
	}
	
	return SomethingDone;
}

//*************************************************************************************************
// RemoveEntryFromDisplay - Pulls the entry out of the main springboard display special section allowing it to
//                                                be "autosorted" into order. This does not insert it into a specific location.
//*************************************************************************************************
BOOL UnHideIconOlder(NSString* Path)
{
	FILE* fp = NULL;
	FILE* Out = NULL;
	char Temp[512];
	int i = 0;
	long PrevLine = 0;
	BOOL Hidden = NO;
	BOOL Changed = NO;
	BOOL SBAppsTags = NO;
	
	if([Path isEqualToString:@"/Applications/Camera.app/Info.plist"] == YES)
	{
		return UnHideSpecialIcon(@"Camera.app", NO);
	}
	else if([Path isEqualToString:@"/Applications/Photos.app/Info.plist"] == YES)
	{
		return UnHideSpecialIcon(@"Photos.app", NO);
	}

	NSString* InfoPlist = [[NSString alloc] initWithString:Path];
	NSString* InfoPlistOut = [[NSString alloc] initWithFormat:@"%@_Info.Out", Path];
	
	if(IsPlistFileBinaryNS(InfoPlist) == YES)
	{
		NSLog(@"UnHideIcon: Plist is still in binary, converting to XML for %@\n", Path);
		ConvertPlistToXml(InfoPlist);
	}
	
	fp = fopen([InfoPlist UTF8String], "r");
	if(fp != NULL)
	{
		// Find the line with >hidden<
		while(!feof(fp))
		{
			if(fgets(Temp, 511, fp) == NULL) break;
			
			// This check is for v0.50 only and can be removed when we are confident none of these versions are out in the field. Also remove if statement below.
			if(strstr(Temp, ">SBAppTags<") != NULL)
			{
				SBAppsTags = YES;
			}
			if(strstr(Temp, ">hidden<") != NULL)
			{
				Hidden = YES;
				break;
			}
			PrevLine++;
		}
		rewind(fp);
		if(Hidden == YES)
		{
			Out = fopen([InfoPlistOut UTF8String], "w");
			if(Out != NULL)
			{
				int LineSubtract = 1;
				
				if(SBAppsTags == YES) LineSubtract = 2;
				for(i = 0; i < PrevLine - LineSubtract; i++)
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}
				
				// Read the 4 lines with SBAppTags, array, hidden, /array
				if(SBAppsTags == YES) fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				fgets(Temp, 511, fp);
				
				while(!feof(fp))
				{
					if(fgets(Temp, 511, fp) == NULL) break;
					fputs(Temp, Out);
				}
				fclose(Out);
			}
			else NSLog(@"Error: 0x%x\n", errno);
		}
		fclose(fp);
		
		if(Hidden == YES)
		{
			remove([InfoPlist UTF8String]);
			rename([InfoPlistOut UTF8String], [InfoPlist UTF8String]);
			Changed = YES;
		}
	}
	
	[InfoPlist release];
	[InfoPlistOut release];
	
	return Changed;
}

//*************************************************************************************************
// UnhideAllIconsAndEmptyList - Determines if the entry is in the master hide list or not.
//*************************************************************************************************
void UnhideAllIconsAndEmptyList()
{
	NSString* MasterList;
	char Temp[256];
	FILE* fp;
	int Length = 0;
	NSString* IconTitle;
	
	MasterList = [[NSString alloc] initWithString:@"/var/mobile/Library/BigBoss/hiddenicons.txt"];
	
	fp = fopen([MasterList UTF8String], "r");
	if(fp != NULL)
	{
		while(!feof(fp))
		{
			if(fgets(Temp, 255, fp) == NULL) break;
			Length = strlen(Temp);
			if(Length > 2)
			{
				if(Temp[Length - 1] == '\r' || Temp[Length - 1] == '\n') Temp[Length - 1] = 0;
				if(Temp[Length - 2] == '\r' || Temp[Length - 2] == '\n') Temp[Length - 2] = 0;
			}
			if(strcmp(Temp, "Camera.app") == 0)
			{
				IconTitle = [[NSString alloc] initWithString:@"/Applications/Camera.app/Info.plist"];
			}
			else if(strcmp(Temp, "Photos.app") == 0)
			{
				IconTitle = [[NSString alloc] initWithString:@"/Applications/Photos.app/Info.plist"];
			}
			else
			{
				IconTitle = [[NSString alloc] initWithFormat:@"%s", Temp];
			}
			UnHideIconOlder(IconTitle);
			HideIcon(IconTitle);
			[IconTitle release];
		}
		fclose(fp);
		remove([MasterList UTF8String]);
	}
	[MasterList release];
}


//*************************************************************************************************
// GetHomeDirectory - Returns the user's home directory
//*************************************************************************************************
NSString* GetHomeDirectory()
{
	return NSHomeDirectory();
}

//*************************************************************************************************
// RunAsRoot - Runs the process command passed in but as user root.
// Note: this should not be run in a threaded env.
//*************************************************************************************************
int RunAsRoot(char* Command)
{
	uid_t UserId = getuid();
	int   ret    = 0;
	
	setuid(0);
	ret = system(Command);
	setuid(UserId);
	
	return ret;
}

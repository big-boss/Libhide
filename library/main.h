
#define Cache_ "/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
#define HIDLIBPATH "/var/mobile/Library/LibHide/hidden.plist"

typedef enum _FILE_ACCESS_TYPE
{
	FILE_READ = 0,
	FILE_WRITE,
	FILE_APPEND
} FILE_ACCESS_TYPE;
BOOL UnHideIconCharPtr(char* Path);
BOOL HideIconCharPtr(char* Path);
BOOL IsIconHiddenCharPtr(char* Path);

BOOL HideLibIsTouch();
BOOL UseRestrictionsForHide(NSString* Path);
BOOL ValidatePlist(char* PlistFile);
BOOL CopyFile(char* Source, char* Dest);
BOOL IsPlistFileBinary(char* Title);
BOOL IsPlistFileBinaryNS(NSString* Path);
char* GetDisplayPlistFile();
void Respring();
char* GetDisplayPlistFileOnly();
BOOL HideIcon(NSString* Path);
BOOL UnHideIcon(NSString* Path);
void ConvertPlistToXml(NSString* Path);
void UnhideAllIconsAndEmptyList();
void UpdateHiddenIconListRemovingTitle(NSString* Title);
NSString* GetHomeDirectory();
BOOL UnHideSpecialIcon(NSString* Path, BOOL UpdateMaster);
int RunAsRoot(char* Command);
BOOL IsIconHidden(NSString* Path);
BOOL UnHideIconOld(NSString* Path);
BOOL HideIconInPlist(NSString* Path);
BOOL IsIconHiddenInfoPlist(NSString* PlistPath);
void RebuildCache();
BOOL IsIconHiddenOld(NSString* Path);
BOOL UnHideIconOlder(NSString* Path);

NSString* GetIconFromPath(NSString* PlistPath);
NSString* GetDisplayNameFromPath(NSString* PlistPath);
NSString* GetBundleFromPath(NSString* PlistPath);
NSString* GetIconFromPlist(NSString* PlistPath);
NSString* GetIconFromFilePath(NSString* ApplicationPath);
NSString* GetPathFromBundleId(NSString* BundleId);
NSString* GetPathFromAppFolderName(NSString* FolderName);

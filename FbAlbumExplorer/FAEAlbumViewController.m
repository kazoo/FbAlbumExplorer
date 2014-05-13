//
//  FAEAlbumViewController.m
//  FbAlbumExplorer
//
//  Created by Ikeda Kazushi on 2014/04/27.
//  Copyright (c) 2014年 Drowsy Dogs, Inc. All rights reserved.
//

#import "FAEAlbumViewController.h"
#import "FbAlbumCollectionCell.h"
#import "SVProgressHUD.h"
#import <FacebookSDK/FacebookSDK.h>

// Facebook Graph Paths
const NSString* GRAPH_PATH_FOR_ME          = @"me?fields=id,name,picture.width(200).height(200).type(small)";
const NSString* GRAPH_PATH_FOR_FRIENDS     = @"me/friends?fields=id,name,picture.width(200).height(200).type(small)";
const NSString* GRAPH_PATH_FOR_ALBUMS      = @"/albums?fields=name,cover_photo";
const NSString* GRAPH_PATH_FOR_COVER_PHOTO = @"?fields=picture,source";
const NSString* GRAPH_PATH_FOR_PHOTOS      = @"/photos?fields=picture,source,name";

// 1セル分の情報を表す内部クラス
@interface FbCellInfo : NSObject

@property NSURL*    url;        // CollectionCell に表示する画像のURL
@property NSString* fbID;       // Facebook Graph（ユーザ/アルバム/フォト)の ObjectID
@property NSString* coverPhotoID;   // アルバムカバーフォトの ObjectID
@property NSString* label;          // CellectionCell 上に表示するラベル
@end

@implementation FbCellInfo
@end



@interface FAEAlbumViewController () {
    NSMutableArray* _fbPhotoList;
    unsigned int    _numOfItemsInSection;
    
}

@property (strong, nonatomic) FBRequestConnection *requestConnection;
@end

@implementation FAEAlbumViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    _fbPhotoList = [NSMutableArray array];

    NSLog(@"album view did load - mode:%d", _mode);
    if (_mode == kFbAccessModeFriends) {
        // create FBLogin Session
        [self startRequestFacebookInfo];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



//
// make sure we have a valid session and call sendRequests.
//
- (void)startRequestFacebookInfo {
    NSLog(@"current FB session state:%x", FBSession.activeSession.state);
    // Check to see whether we have already opened a session.
    if (FBSession.activeSession.isOpen) {
        // login is integrated with the send button, but we need to check permission
        if ([[FBSession.activeSession permissions] indexOfObject:@"friends_photos"] == NSNotFound) {
            [FBSession.activeSession requestNewReadPermissions:@[@"user_photos", @"friends_photos"]
                                             completionHandler:^(FBSession *session,
                                                                 NSError *error) {
                                                 if (error) {
                                                     FBErrorCategory category = [FBErrorUtility errorCategoryForError:error];
                                                     NSLog(@"request new permission error -category:%d", (int)category);
                                                 } else {
                                                     [self sendRequestsWithFbId:[NSArray arrayWithObject:GRAPH_PATH_FOR_ME]];
                                                 }
                                             }
             ];
        } else {
            [self sendRequestsWithFbId:[NSArray arrayWithObject:GRAPH_PATH_FOR_ME]];
        }
    } else {
        BOOL loginUI;
        if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
            loginUI = NO;
        } else {
            loginUI = YES;
        }
        NSLog(@"open active session for read permission");
        [FBSession openActiveSessionWithReadPermissions:@[@"user_photos", @"friends_photos"]
                                           allowLoginUI:loginUI
                                      completionHandler:^(FBSession *session,
                                                          FBSessionState status,
                                                          NSError *error) {
                                          [self sessionStateChanged:session state:status error:error];
                                      }];
    }
}



// This method will handle ALL the session state changes in the app
- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error
{
    NSLog(@"FB session state changed : %x", state);
    
    // If the session was opened successfully, start request
    if (!error && (state == FBSessionStateOpen || state == FBSessionStateOpenTokenExtended)){
        NSLog(@"FB session opened");
        [self sendRequestsWithFbId:[NSArray arrayWithObject:GRAPH_PATH_FOR_ME]];
        return;
    }
    
    if (state == FBSessionStateClosed || state == FBSessionStateClosedLoginFailed){
        NSLog(@"FB session closed");
        // Show the user the LogIn UI ?
    }
    
    // Handle errors
    if (error){
        NSLog(@"FB session error: %@", error.localizedDescription);
        NSString *alertTitle = @"FB Session Error";
        NSString *alertText = [FBErrorUtility userMessageForError:error]; // FacebookSDKOverride.bundle でローカライズされる
        
        // If the error requires people using an app to make an action outside of the app in order to recover
        if ([FBErrorUtility shouldNotifyUserForError:error] == YES){
            [self showMessage:alertText withTitle:alertTitle];
            // ...
        } else {
            // If the user cancelled login, do nothing
            if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
                NSLog(@"User cancelled login");
                
                // Handle session closures that happen outside of the app
            } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession){
                [self showMessage:alertText withTitle:alertTitle];
                
                // For simplicity, here we just show a generic message for all other errors
                // You can learn how to handle other errors using our guide: https://developers.facebook.com/docs/ios/errors
            } else {
                //Get more error information from the error
                NSDictionary *errorInformation = [[[error.userInfo objectForKey:@"com.facebook.sdk:ParsedJSONResponseKey"] objectForKey:@"body"] objectForKey:@"error"];
                NSLog(@"unknown error: %@", [errorInformation objectForKey:@"message"]);
                [self showMessage:alertText withTitle:alertTitle];
            }
        }
        // Clear this token
        [FBSession.activeSession closeAndClearTokenInformation];
        // Show the user the Login UI ?
    }
}

// Read the ids to request from textObjectID and generate a FBRequest
// object for each one.  Add these to the FBRequestConnection and
// then connect to Facebook to get results.  Store the FBRequestConnection
// in case we need to cancel it before it returns.
//
// When a request returns results, call requestComplete:result:error.
- (void)sendRequestsWithFbId:(NSArray*)fbids {
    
    if (!fbids) {
        fbids = [NSArray arrayWithObject:GRAPH_PATH_FOR_ME];
    }
    NSLog(@"send request with Fb ID:%@", fbids);
    
    // create the connection object
    FBRequestConnection *newConnection = [[FBRequestConnection alloc] init];
    
    // for each fbid in the array, we create a request object to fetch
    // the profile, along with a handler to respond to the results of the request
    for (NSString *fbid in fbids) {
        
        // create a handler block to handle the results of the request for fbid's profile
        FBRequestHandler handler =
        ^(FBRequestConnection *connection, id result, NSError *error) {
            // output the results of the request
            [self requestCompleted:connection forFbID:fbid result:result error:error];
        };
        
        // create the request object, using the fbid as the graph path
        // as an alternative the request* static methods of the FBRequest class could
        // be used to fetch common requests, such as /me and /me/friends
        
        FBRequest *request = [[FBRequest alloc] initWithSession:FBSession.activeSession
                                                      graphPath:fbid];
        
        // add the request to the connection object, if more than one request is added
        // the connection object will compose the requests as a batch request; whether or
        // not the request is a batch or a singleton, the handler behavior is the same,
        // allowing the application to be dynamic in regards to whether a single or multiple
        // requests are occuring
        [newConnection addRequest:request completionHandler:handler];
    }
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeNone];
    
    // if there's an outstanding connection, just cancel
    [self.requestConnection cancel];
    
    // keep track of our connection, and start it
    self.requestConnection = newConnection;
    [newConnection start];
}


// Report any results.  Invoked once for each request we make.
- (void)requestCompleted:(FBRequestConnection *)connection
                 forFbID:fbID
                  result:(id)result
                   error:(NSError *)error {
    // not the completion we were looking for...
    if (self.requestConnection &&
        connection != self.requestConnection) {
        return;
    }
    
    // clean this up, for posterity
    self.requestConnection = nil;
    
    NSLog(@"Responsed for graph path %@", (NSString*)fbID);
    
    if (error) {
        [self showMessage:NSLocalizedString(@"fbConnectionErrorMsg", nil)
                withTitle:NSLocalizedString(@"fbConnectionErrorTitle", nil)];
    } else {
        // result is the json response from a successful request
        NSDictionary *dic = (NSDictionary *)result;
        
        //        // debug
        //        for (id key in dic) {
        //            NSLog(@"%@: %@", key, [dic objectForKey:key]);
        //        }

        if ([fbID isEqualToString:(NSString*)GRAPH_PATH_FOR_ME]) {
            [self parseResponseForMe:dic];
        } else if ([fbID  isEqualToString:(NSString *)GRAPH_PATH_FOR_FRIENDS]) {
            [self parseResponseForFriends:dic];
        } else if ([fbID hasSuffix:(NSString*)GRAPH_PATH_FOR_ALBUMS]){
            [self parseResponseForAlbums:dic];
        } else if ([fbID hasSuffix:(NSString*)GRAPH_PATH_FOR_COVER_PHOTO]) {
            [self parseResponseForCoverPhotos:dic];
        } else if ([fbID hasSuffix:(NSString*)GRAPH_PATH_FOR_PHOTOS]) {
            [self parseResponseForPhotos:dic];
        } else {
            NSLog(@"unknown graph path: %@", fbID);
            [SVProgressHUD  dismiss];
        }
        
    }
    
    
}



#pragma mark - Response Parser
- (void)parseResponseForMe:(NSDictionary*)response
{
    NSLog(@"parse response for 'me'");
    // 最初のリクエストなのでデータクリア
    [_fbPhotoList removeAllObjects];
    
    // 1セル分のデータ作成
    FbCellInfo* cell = [[FbCellInfo alloc] init];
    
    // 自分のID、名前、写真URLを取得　→ URLの画像リクエストは非同期でColletionViewのDelegateから行う
    NSString* pictureSrc = [[[response objectForKey:@"picture"] objectForKey:@"data"] objectForKey:@"url"];
    //    NSString* pictureSrc = [[response objectForKey:@"data"] objectForKey:@"url"];
    NSLog(@"my picture URL: %@", pictureSrc);
    NSURL* url = [NSURL URLWithString:pictureSrc];
    [cell setUrl:url];
    
    // ラベル（ユーザの名前）は先に表示できるようにリストに追加
    NSString* label = [response objectForKey:@"name"];
    [cell setLabel:label];
    
    // 次のレベルのリクエストのためにfbidを記録
    NSString *myID = [response objectForKey:@"id"];
    NSLog(@"added ID: %@", myID);
    [cell setFbID:myID];
    
    // Friendsリストに追加
    [_fbPhotoList addObject:cell];
    _numOfItemsInSection = 1;
    
    // 再描画
    [_fbAlbumCollectionView reloadData];
    
    // 続いて友達一覧をリクエスト
    NSArray* reqFriendsList = [NSArray arrayWithObject:GRAPH_PATH_FOR_FRIENDS];
    [self sendRequestsWithFbId:reqFriendsList];
    
}

- (void)parseResponseForFriends:(NSDictionary*)response
{
    NSLog(@"parse response for friends");
    // 友達一覧のID、名前、写真URL取得完了→ プロファイル画像は非同期でリクエスト
    NSArray* dataArray = [response objectForKey:@"data"];
    if (dataArray != nil) {
        for (NSDictionary* usrData in dataArray) {
            // 1セル分のデータ作成
            FbCellInfo* cell = [[FbCellInfo alloc] init];
            
            // Friends' Picture URL
            NSString* friendsPicUrl = [[[usrData objectForKey:@"picture"] objectForKey:@"data"] objectForKey:@"url"];
            NSLog(@"Friends Pic URL: %@", friendsPicUrl);
            
            // URLを記録
            NSURL *url   = [NSURL URLWithString:friendsPicUrl];
            [cell setUrl:url];
            
            // ラベル
            NSString* label = [usrData objectForKey:@"name"];
            [cell setLabel:label];
            
            // 次レベルのための FBID 記録
            NSString* fbid = [usrData objectForKey:@"id"];
            NSLog(@"added ID: %@", fbid);
            [cell setFbID:fbid];
            
            [_fbPhotoList addObject:cell];
        }

        _numOfItemsInSection = [_fbPhotoList count];

        // ラベルが入った段階でリロード
        [_fbAlbumCollectionView reloadData];
        
        [SVProgressHUD dismiss];
    }
}


- (void)parseResponseForAlbums:(NSDictionary*)response
{
    // アルバムコレクションをクリア
    [_fbPhotoList removeAllObjects];
    
    NSLog(@"start cover photo requests");
    // カバーフォト一覧を取得するためのリクエストを作成
    NSMutableArray* reqAlbumCoverPhotos = [NSMutableArray array];
    NSArray* dataArray = [response objectForKey:@"data"];
    int coverPhotoCount = [dataArray count];
    NSLog(@"cover photo count:%d", coverPhotoCount);
    if (coverPhotoCount == 0) {
        // カバーフォトが0枚。できればメッセージ出す
        [SVProgressHUD dismiss];
        return;
    }
    for (id album in dataArray) {
        // 1セル分のデータ作成
        FbCellInfo* cell = [[FbCellInfo alloc] init];
        NSString* albumID      = [album objectForKey:@"id"];
        NSString* coverPhotoID = [album objectForKey:@"cover_photo"];
        if (coverPhotoID == nil) {
            // カバーフォトは存在しない場合がある
            continue;
        }
        NSString* label = [album objectForKey:@"name"];
        [cell setFbID:albumID];
        [cell setCoverPhotoID:coverPhotoID];
        [cell setLabel:label];
        
        // カバーフォト画像のリクエストメッセージを追加
        NSString* coverPhotoGraph = [NSString stringWithFormat:@"%@%@", coverPhotoID, @"?fields=picture,source"];
        [reqAlbumCoverPhotos addObject:coverPhotoGraph];
        
        // タップ時のために記録
        [_fbPhotoList addObject:cell];
        
    }
    // カバーフォト一覧をリクエスト
    NSLog(@"start cover photo request");
    [self sendRequestsWithFbId:(NSArray*)reqAlbumCoverPhotos];
    
}

- (void)parseResponseForCoverPhotos:(NSDictionary*)response
{
    // 取得したカバーフォトのインデックスを取得
    NSString* coverPhotoId = [response objectForKey:@"id"];
    // albumList からそのIDを探す
    FbCellInfo* albumInfo;
    for (FbCellInfo *album in _fbPhotoList) {
        if ([coverPhotoId compare:album.coverPhotoID] == NSOrderedSame) {
            albumInfo = album;
            break;
        }
    }
    if (!albumInfo) {
        NSLog(@"album not found from cover photo response ID");
        return;
    }
    
    albumInfo.url = [NSURL URLWithString:[response objectForKey:@"source"]];
    [_fbAlbumCollectionView reloadData];   // TODO: リロードのタイミング再考
    [SVProgressHUD dismiss];
    
}

- (void) parseResponseForPhotos:(NSDictionary*)response
{
    // フォトコレクションをクリア
    [_fbPhotoList removeAllObjects];
    
    // 写真一覧の picture と source を取得
    NSArray *photoArray = [response objectForKey:@"data"];
    for (id photo in photoArray) {
        // 1セル分のデータ作成
        FbCellInfo* cell = [[FbCellInfo alloc] init];
        
        NSString* photoURL = [photo objectForKey:@"source"];
        NSLog(@"photo URL: %@", photoURL);
        NSURL* url = [NSURL URLWithString:photoURL];
        [cell setUrl:url];
                
        [_fbPhotoList addObject:cell];
        
    }
    [_fbAlbumCollectionView reloadData];    // TODO: リロードのタイミング再考
    [SVProgressHUD  dismiss];
}


#pragma mark - CollectionView Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [_fbPhotoList count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    FbAlbumCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"FbAlbumCollectionCellID" forIndexPath:indexPath];
    @try {
        FbCellInfo* info = [_fbPhotoList objectAtIndex:indexPath.row];
        
        if (info) {
            cell.collectionCellLabel.text = info.label;
            NSURL *url = info.url;

            dispatch_queue_t q_global, q_main;
            q_global = dispatch_get_global_queue(0, 0);
            q_main = dispatch_get_main_queue();
            
            dispatch_async(q_global, ^{
                NSData *data = [NSData dataWithContentsOfURL:url];
                UIImage *image = [UIImage imageWithData:data];
                
                dispatch_async(q_main, ^{
                    cell.imageView.image = image;
                });
            });
            
        }
    } @catch (NSException *exception) {
        NSLog(@"cell index error?");
        cell.collectionCellLabel.text = @"";
    }
    
    return cell;
}


- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Tapped %ld-%ld", indexPath.section, indexPath.row);
    unsigned long index = indexPath.row;
    
    if (_mode == kFbAccessModeFriends) {
        FbCellInfo* info = [_fbPhotoList objectAtIndex:index];
        // album list request in next level VC
        FAEAlbumViewController* nextVC = [[self storyboard] instantiateViewControllerWithIdentifier:@"FacebookAlbumVC"];
        [nextVC setMode:kFbAccessModeAlbums];
        [nextVC setDelegate:self.delegate]; // 孫請け登録

        [self.navigationController pushViewController:nextVC animated:YES];
        
        // 次のレベルのVCにリクエスト：指定ユーザのアルバム一覧
        NSString* reqAlbumList = [NSString stringWithFormat:@"%@%@", info.fbID, GRAPH_PATH_FOR_ALBUMS];
        [nextVC sendRequestsWithFbId:[NSArray arrayWithObject:reqAlbumList]];

    } else if (_mode == kFbAccessModeAlbums) {
        FbCellInfo* info = [_fbPhotoList objectAtIndex:index];
        // photo list request in next level VC
        FAEAlbumViewController* nextVC = [[self storyboard] instantiateViewControllerWithIdentifier:@"FacebookAlbumVC"];
        [nextVC setMode:kFbAccessModePhotos];
        [nextVC setDelegate:self.delegate]; // 孫請け登録

        [self.navigationController pushViewController:nextVC animated:YES];
        
        // 次のレベルのVCにリクエスト：指定アルバムのフォト一覧
        NSString* reqPhotoList = [NSString stringWithFormat:@"%@%@", info.fbID , GRAPH_PATH_FOR_PHOTOS];
        [nextVC sendRequestsWithFbId:[NSArray arrayWithObject:reqPhotoList]];

    } else if (_mode == kFbAccessModePhotos) {
        FbCellInfo* info = [_fbPhotoList objectAtIndex:index];
        // 高画質版のフォトをあらためて取得する（同期）
        NSData* data = [NSData dataWithContentsOfURL:info.url];
        UIImage* image = [UIImage imageWithData:data];
        
        // 再帰的に delegate
        if ([_delegate respondsToSelector:@selector(facebookAlbumPicker:didFinishPickingFbPhoto:)]) {
            [_delegate facebookAlbumPicker:self didFinishPickingFbPhoto:image];
        }
        
        // LoginVC に戻るようにpopする
        [self.navigationController popToViewController:[self.navigationController.viewControllers objectAtIndex:0] animated:YES];
    }
}

// recursive delegate
- (void)facebookAlbumPicker:(FAEAlbumViewController *)picker didFinishPickingFbPhoto:(UIImage *)image
{
    if ([_delegate respondsToSelector:@selector(facebookAlbumPicker:didFinishPickingFbPhoto:)]) {
        NSLog(@"didFinishPickingFbPhoto - mode:%d", _mode);
        [self.navigationController popViewControllerAnimated:YES];
        [_delegate facebookAlbumPicker:self didFinishPickingFbPhoto:image];
    }
}

// Show an alert message
- (void)showMessage:(NSString *)text withTitle:(NSString *)title
{
    [[[UIAlertView alloc] initWithTitle:title
                                message:text
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}


- (IBAction)backButtonTapped:(id)sender {
    [SVProgressHUD  dismiss];
    [self.navigationController popViewControllerAnimated:YES];    
}


@end

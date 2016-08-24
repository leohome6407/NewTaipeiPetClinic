//
//  ViewController.m
//  FindingPetClinic
//
//  Created by 李岳 on 2016/6/20.
//  Copyright © 2016年 Yue Li. All rights reserved.
//

#import "ViewController.h"
#import "Reachability.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface ViewController ()<MKMapViewDelegate,CLLocationManagerDelegate,UIAlertViewDelegate>
{
    CLLocationManager *locationManager;
    CLLocation *currentLocation;
    CLLocationCoordinate2D targetCoordinate;
    CLLocationCoordinate2D addresscoordinate;
    NSArray *json;
    NSString *placeName;
    MKPointAnnotation *point;
    NSMutableString *addressname;
    NSString *telephone;
    NSDictionary *newTaipeJson;
}

@property (weak, nonatomic) IBOutlet MKMapView *mainMapView;

@end

@implementation ViewController

-(void) viewDidAppear:(BOOL)animated{
    [self CheckNetwork];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self getPetClinicAPI];
    [self PrepareLocationManager];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark 檢測網路連線
-(void)CheckNetwork {

    Reachability * networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus =[networkReachability currentReachabilityStatus];
    if (networkStatus == NotReachable) {
        UIAlertController * noInterNet =[UIAlertController alertControllerWithTitle:@"網路異常，請連接網路" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction * ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [noInterNet addAction:ok];
        
        [self presentViewController:noInterNet animated:true completion:nil];
    }
    else{
        Reachability * reachability =[Reachability reachabilityForInternetConnection];
        [reachability startNotifier];
        NetworkStatus status =[reachability currentReachabilityStatus];
        if (status == NotReachable) {
        }
    }
}

#pragma mark 準備地圖
-(void)PrepareLocationManager {
    
    locationManager.delegate = self;
    _mainMapView.userTrackingMode = MKUserTrackingModeFollow;
    _mainMapView.userLocation.title = @"目前位置";
    locationManager = [CLLocationManager new];
    
    if([locationManager respondsToSelector:@selector
        (requestAlwaysAuthorization)]){
        [locationManager requestAlwaysAuthorization];
    }
    
    //Prepare locationManager
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.activityType = CLActivityTypeAutomotiveNavigation;
    locationManager.delegate = self;
    [locationManager startUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate Methods
-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{   
    currentLocation = locations.lastObject;
    
    // Make the region change just once   只跑一次
    static dispatch_once_t changeRegionOnceToken;
    dispatch_once(&changeRegionOnceToken, ^{
        MKCoordinateRegion region = _mainMapView.region;
        region.center = currentLocation.coordinate;
        region.span.latitudeDelta = 0.01;   //控制地圖大小
        region.span.longitudeDelta = 0.01;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_mainMapView setRegion:region animated:true];
        });
    });
}

#pragma mark 取得醫院資料
- (void)getPetClinicAPI {
    //取得醫院資料
    NSString *urlString = [NSString stringWithFormat:@"https://raw.githubusercontent.com/leohome6407/PetClinic/master/NewTaipei.json"];
    
    //包裝成url
    NSURL *url = [NSURL URLWithString:urlString];
    
    //Prepare NSURLSession
    //產生一組設定                                                    產生的方法↓
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    //傳回
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"Error: %@",error);
            return ;
        }
        
        json = [[NSArray alloc]initWithArray:[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil]];
        
        for (int i=0; i<json.count; i++) {
            newTaipeJson = json[i];
            NSString *Lat = [newTaipeJson valueForKey:@"Latitude"];
            NSString *Lon = [newTaipeJson valueForKey:@"Longitude"];
            addressname = [newTaipeJson valueForKey:@"Name"];
            telephone = [newTaipeJson valueForKey:@"Tel"];
            addresscoordinate.latitude = Lat.doubleValue;
            addresscoordinate.longitude = Lon.doubleValue;
            point = [MKPointAnnotation new];
            point.coordinate = addresscoordinate;
            point.title =addressname;
            point.subtitle =telephone;
            
            [_mainMapView addAnnotation:point];
        }
    }];
    [task resume];
}

#pragma mark 大頭針點擊觸發buttonTapped:方法
-(MKAnnotationView*)mapView:(MKMapView *)mapViiew viewForAnnotation:(id<MKAnnotation>)annotation{
    //控制藍點顯示
    if(annotation == mapViiew.userLocation){
        
        return nil;
    }
    NSString *identifier = @"Store";
    
    MKAnnotationView *result = [mapViiew dequeueReusableAnnotationViewWithIdentifier:identifier];
    if(result == nil){
        
        result = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
    }else{
        result.annotation = annotation;
    }
    
    result.canShowCallout = YES;
    
    
    //Show Our own image
    UIImage *annotationImage = [UIImage imageNamed:@"pointRed.png"];
    result.image = annotationImage;
    
    //Left vallout sccessory view
    //result.leftCalloutAccessoryView = [[UIImageView alloc] initWithImage:annotationImage];
    
    
    // Right callout accessory view
    UIButton *button = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    result.rightCalloutAccessoryView = button;
    
    return result;}

#pragma mark Alert Button 控制
-(void) buttonTapped:(id) sender{
    [self getAnno];
    NSString *message =telephone;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:placeName message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *callTel = [UIAlertAction actionWithTitle:@"打電話" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        NSString *telephoneString=[telephone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSMutableString *str1=[[NSMutableString alloc] initWithString:telephoneString];
        [str1 setString:[str1 stringByReplacingOccurrencesOfString:@"(" withString:@""]];
        [str1 setString:[str1 stringByReplacingOccurrencesOfString:@")" withString:@""]];
        [str1 setString:[str1 stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        [str1 setString:[str1 stringByReplacingOccurrencesOfString:@" " withString:@""]];
        telephoneString = [@"tel://" stringByAppendingString:str1];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telephoneString]];
                                                         }];
    [alert addAction:callTel];

    UIAlertAction *otherButton = [UIAlertAction actionWithTitle:@"導航"style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        if ([[UIApplication sharedApplication] canOpenURL:
             [NSURL URLWithString:@"comgooglemaps://"]]) {
            [self googleMaps];
        } else {
            NSURL *itunesURL = [NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id585027354"];
            [[UIApplication sharedApplication] openURL:itunesURL];
        }
                                                        }];
    [alert addAction:otherButton];
    
    UIAlertAction * cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:true completion:nil];

}

#pragma mark 放大did select annotation
- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(nonnull MKAnnotationView *)view{
    [self getAnno];
    MKCoordinateRegion region = _mainMapView.region;
    region.center = targetCoordinate;
    region.span.latitudeDelta = 0.01;
    region.span.longitudeDelta = 0.01;
    [_mainMapView setRegion:region animated:true];
}


#pragma mark Get the Annotation's coordinate, title and subtitle.
- (void)getAnno{
    
    if (_mainMapView.selectedAnnotations.count == 0)
    {
        NSLog(@"no annotation selected");
    }
    else
    {
        id<MKAnnotation> ann = [_mainMapView.selectedAnnotations objectAtIndex:0];
        targetCoordinate = ann.coordinate;
        placeName = ann.title;
        telephone = ann.subtitle;
    }
}

#pragma mark Google導航
-(void)googleMaps {
    [self PrepareLocationManager];
    NSString *stringToAddr = [NSString stringWithFormat:@"%f ,%f",addresscoordinate.latitude,addresscoordinate.longitude];
    NSString *stringFromAddr = [NSString stringWithFormat:@"%f ,%f",currentLocation.coordinate.latitude,currentLocation.coordinate.longitude];
    NSString *stringURLContent = [NSString stringWithFormat:@"comgooglemaps://?daddr=%@&saddr=%@",stringToAddr ,stringFromAddr];
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[stringURLContent stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

@end

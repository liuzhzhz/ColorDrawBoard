//
//  TSHBoard.m
//  TuShou
//
//  Created by liu on 16/3/14.
//  Copyright © 2016年 tujiao. All rights reserved.
//
#define CoderPathColor  @"CoderPathColor"
#define CoderBezierPath @"CoderBezierPath"
#define PerPointsSeconds 0.01
#define EraserLineWidth (kScreen_Width/16) //最大的线宽的2.5倍
#import "UIImage+TSH.h"
#import "NSString+TSH.h"
#import "TSHBoard.h"
#import "TSHTopic.h"
#import "TSHDrawCotent.h"
#import "UIView+TSH.h"
#import "TSHDrawCommon.h"
#import "UIColor+TSH.h"
#import "TSHDrawPoint.h"
#import "MJExtension.h"
//#import "PINDiskCache.h"
#import "Config.h"
#import <QuartzCore/QuartzCore.h>
#import "macro.h"
#import "UMMobClick/MobClick.h"
#import "UserManager.h"

typedef enum {
    ActionChangeBackground = 1,
    ActionPlaying,
    ActionGoback,
    ActionGoforward,
    ActionClearAll
} Action;

@interface TSHBoard()
{
    NSInteger _drawContenID;
    UIColor *_lastColor;
    CGFloat _lastLineWidth;
    CGFloat _lastInterval;      // 算间隔时间
    CGFloat _totalTime;
    CGFloat _zoomScale;
    //串行队列
    dispatch_queue_t mainQueue;
    /**x坐标比值*/
    CGFloat _xP;
    /**y坐标比值*/
    CGFloat _yP;
    //stop状态
    BOOL isStop;
    //是否有绘画轨迹
    NSInteger isExitDrawModel;
    BOOL isReadLocalData;
    int _index;
    BOOL _isExitBackPath;//是否存在撤销
    //    CGPoint startPoint;
}
//@property (copy, nonatomic) drawStatusBlock statusBlock;
@property (copy, nonatomic) completePlayDrawing  completePlayBlock;
@property (copy, nonatomic) boardImageBlock boardImage;
@property (strong, nonatomic) NSArray *backDrawArr ;
@property (strong, nonatomic) NSMutableArray *localPaths;
//@property (strong, nonatomic) TSHCAShapeLayer *drawLayer ;
@property (strong, nonatomic) NSMutableArray *localTempPoints;
@property (strong, nonatomic) NSMutableArray *tempPoints;//用于存 绘制bezier曲线时所需的点

@property (strong, nonatomic) NSMutableArray *localTempPath;

@property (strong, nonatomic) NSMutableArray *needSaveModels ;

@property (strong, nonatomic) NSMutableArray *remoteModels;     // 接收的全部轨迹模型

@property (strong, nonatomic) NSMutableArray *remotePaths;      // 接收的轨迹

@property (strong, nonatomic) NSMutableArray *remoteTempPaths;  // 用于撤销前进
//@property (strong, nonatomic) TSHDrawModel *remoteTempModel ;
@property (strong, nonatomic) NSMutableArray *remoteTempModels;  // 用于撤销前进fifo队列

@property (strong, nonatomic) NSMutableArray *remotePoints;     // 回放pointList

@property (strong, nonatomic) TSHPath *remoteTempPath;           // 临时单个Path
@property (strong, nonatomic) TSHDrawPoint *remoteTempPoint;     // 临时单个Point

@property (assign, nonatomic) NSUInteger pointsCounter;
@property (strong, nonatomic) NSMutableArray *pointsArray;

/**并行队列 默认MaxCurrentOperation ＝ 1*/
//@property (strong, nonatomic) NSOperationQueue * myQueue ;

@property (copy, nonatomic) drawingProgressBlock drawingProgressCb;
@property (strong, nonatomic) TSHPath *bezierPath;
@end

static BOOL ise = NO;

@implementation TSHBoard

//-(void)loadGestures
//{
////    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
////    self.panRecognizer.maximumNumberOfTouches = 1;
////    [self addGestureRecognizer:self.panRecognizer];
////
////    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
////    [self addGestureRecognizer:self.tapRecognizer];
//}

- (void)redrawWhenReciveSliderValueChanged:(CGFloat)userChangeSliderValue
{
    CGFloat countTime = 0;
    _lastInterval = 0;
    _index = 0;
    for (TSHDrawModel* mo in self.remoteModels)
    {
        countTime = countTime + mo.pointList.count * PerPointsSeconds;
    }
    _totalTime = countTime;
    CGFloat returnTime = countTime * userChangeSliderValue;
    
    countTime = 0;
    TSHDrawModel *model = self.backDrawArr.firstObject;
    CGFloat xp = self.width / model.width.floatValue ;
    CGFloat yp = self.height / model.hight.floatValue ;
    _xP = xp;
    _yP = yp;
    for (int i = 0; i < self.backDrawArr.count; i = i+1)
    {
        TSHDrawModel *model = self.backDrawArr[i];
        self.remotePoints = [NSMutableArray arrayWithArray:model.pointList];
        for (int j=0; j< model.pointList.count; j++)
        {
            TSHDrawPoint *point = model.pointList[j];
            _lastInterval = _lastInterval + PerPointsSeconds;
            if (j == 0)
            {
                CGPoint startPoint = CGPointMake(point.x*_xP,
                                                 point.y*_yP);
                TSHPath *path = [TSHPath pathToPoint:startPoint pathWidth:model.paintSize.floatValue*_xP];
                path.pathColor = [UIColor colorWithHexString:model.paintColor];
                path.isEraser = model.isEraser.boolValue;
                if (path.isEraser)
                {
                    path.pathColor = [UIColor clearColor];
                }
                //                [self.tempPoints removeAllObjects];
                //                [self.tempPoints addObject:point];
                
                [self.localPaths addObject:path];
            }
            else
            {
                TSHPath *path = [self.localPaths lastObject];
                path.endPoint = CGPointMake(point.x*_xP, point.y*_yP);
                path.controlPoint1 = CGPointMake(point.controllPoint1x*_xP, point.controllPoint1y*_yP) ;
                path.controlPoint2 = CGPointMake(point.controllPoint2x*_xP, point.controllPoint2y*_yP) ;
                [path drawPathLine:pathDrawTypeMove];
            }
            
            countTime = countTime + PerPointsSeconds;
            
            if ( self.remotePoints.count>0)
            {
                [ self.remotePoints removeObjectAtIndex:0];
            }
            
            if (countTime>=returnTime)
            {
                if(self.remotePoints.count == 0)
                    _index++;
                return  ;
            }
        }
        _index++;
        //        if (self.remoteModels.count>0)
        //        {
        //            [self.remoteModels removeObjectAtIndex:0];
        //        }
    }
}

- (void)loadInitStep
{
    _isExitBackPath = NO;
    
    _isPause = NO;
    isStop = NO;
    isExitDrawModel = 0;
    _zoomScale = 1.0;
    //串行队列
    mainQueue = dispatch_get_main_queue();
    //    globalQueue = dispatch_get_global_queue(0, 0);
    //    [self myQueue];
    self.bgColor = [UIColor colorWithHexString:@"#FFFFFF"];
    self.backgroundColor = [UIColor clearColor];
    //    [self loadGestures];
    //    __weak __typeof(self) weakSelf = self;
    
    //    [[NSNotificationCenter defaultCenter]addObserverForName:SliderValueChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    //        if ([note.userInfo[@"id"] integerValue] == _drawContenID)
    //        {
    //
    //            _isPause = YES;
    //            CGFloat userChangeSliderValue = [note.object floatValue];
    //            [weakSelf removeDrawingData];
    //            if (userChangeSliderValue==0)
    //            {
    //                [weakSelf setNeedsDisplay];
    //                return ;
    //            }
    //            weakSelf.remoteModels = [NSMutableArray arrayWithArray:weakSelf.backDrawArr];
    //            [weakSelf redrawWhenReciveSliderValueChanged:userChangeSliderValue];
    //        }
    //    }];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self loadInitStep];
        self.layer.drawsAsynchronously = YES;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self loadInitStep];
        self.layer.drawsAsynchronously = YES;
    }
    return self;
}

#pragma mark - Public_Methd
- (void)addUploadFileOperationBlock:(completePlayDrawing)voidBlock
{
    //    [self.myQueue addOperationWithBlock:voidBlock];
}

- (void)sliderValueChanged:(CGFloat)scale drawID:(NSInteger)drawID
{
    if (drawID == _drawContenID)
    {
        
        _isPause = YES;
        [self removeDrawingData];
        if (scale == 0)
        {
            [self setNeedsDisplay];
            return ;
        }
        self.remoteModels = [NSMutableArray arrayWithArray:self.backDrawArr];
        [self redrawWhenReciveSliderValueChanged:scale];
        [self drawAllPath];
    }
}

- (void)setDrawingProgressBlock:(drawingProgressBlock)cb
{
    self.drawingProgressCb = cb;
}

- (void)changeEraserLineWidth:(CGFloat)scale
{
    _zoomScale = scale;
    if (ise)
    {
        self.lineWidth = EraserLineWidth/scale;
    }
}

- (void)stopPlayDrawing
{
    //    for (NSOperation*oper in self.myQueue.operations)
    //    {
    //        [oper cancel];
    //    }
    //    [self.myQueue cancelAllOperations];
    isStop = YES;
    [self removeDrawingData];
    self.backDrawArr = nil;
    //    globalQueue = nil;
}

- (void)removeDrawingData
{
    [self.remoteModels removeAllObjects];
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
    self.cachedImage = nil;
    self.remoteModels = nil;
    [self.localPaths removeAllObjects];
}

- (void)removeAllGestureRecognizers
{
    //    [self removeGestureRecognizer:self.tapRecognizer];
    //    [self removeGestureRecognizer:self.panRecognizer];
}

- (void)clearDataExpextUploadData
{
    self.cachedImage = nil;
    [self.localPaths removeAllObjects];
    isExitDrawModel = 0;
    [self.localTempPoints removeAllObjects];
    [self.localTempPath removeAllObjects];
    [self.remoteModels removeAllObjects];
    [self removeLocalHistoryJsonFile];
}

- (void)clearAll
{
    self.cachedImage = nil;
    [self.localPaths removeAllObjects];
    isExitDrawModel = 0;
    [UIView transitionWithView:self duration:0.2f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self setNeedsDisplay];
                    }
                    completion:nil];
    [self.localTempPoints removeAllObjects];
    [self.localTempPath removeAllObjects];
    [self.needSaveModels removeAllObjects];
    [self.remoteModels removeAllObjects];
    [self removeLocalHistoryJsonFile];
}

- (void)goBack
{
    _lastInterval = CFAbsoluteTimeGetCurrent();
    if (self.localPaths.count>0)
    {
        _isExitBackPath = YES;
        if ([self.localPaths lastObject]){
            [self.localTempPath addObject:[self.localPaths lastObject]];
        }
        [self.localPaths removeLastObject];
        [self.remoteTempModels addObject:[self.needSaveModels lastObject]];
        [self.needSaveModels removeLastObject];
        //        __weak __typeof(self) weakSelf = self;
        //        //        [self.myQueue addOperationWithBlock:^{
        //        NSData *data = [weakSelf getCurrentDrawingJsonFile];
        //        NSString *str = [data mj_JSONString];
        //        NSArray *arr = [str mj_JSONObject];
        //        NSMutableArray *muArr = [TSHDrawModel mj_objectArrayWithKeyValuesArray:arr];
        //        [muArr removeLastObject];
        //        [weakSelf writeAllModelToJsonFileWith:muArr];
        //        weakSelf.remoteTempModel = [muArr lastObject];
        //        //        }];
        
        [self drawAllPath];
        isExitDrawModel--;
        [[NSNotificationCenter defaultCenter] postNotificationName:Action_RefreshThumbnail object:nil];
    }
}

- (void)goForward
{
    _lastInterval = CFAbsoluteTimeGetCurrent();
    if (self.remoteTempModels.count>0)
    {
        if ([self.localTempPath lastObject]){
            [self.localPaths addObject:[self.localTempPath lastObject]];
            [self.needSaveModels addObject:[self.remoteTempModels lastObject]];
        }
        //        TSHDrawModel* model = ;
        //        __weak __typeof(self) weakSelf = self;
        //        //        [self.myQueue addOperationWithBlock:^{
        //        NSData* data = [weakSelf getCurrentDrawingJsonFile];
        //        NSString * str = [data mj_JSONString];
        //        NSArray * arr = [str mj_JSONObject];
        //        NSMutableArray* muArr = [TSHDrawModel mj_objectArrayWithKeyValuesArray:arr];
        //        if (!muArr)
        //        {
        //            muArr = [NSMutableArray new];
        //        }
        //        [muArr addObject:model];
        //        [weakSelf writeAllModelToJsonFileWith:muArr];
        [self.remoteTempModels removeLastObject];
        //        weakSelf.remoteTempModel = model;
        //        }];
        [self.localTempPath removeLastObject];
        [self drawAllPath];
        isExitDrawModel++;
        [[NSNotificationCenter defaultCenter] postNotificationName:Action_RefreshThumbnail object:nil];
    }
}

/**暂停绘画*/
- (void)pauseDrawing
{
    _isPause = YES;
}

/**继续绘画*/
- (void)continueDrawing
{
    _isPause = NO;
    if (!_isPause)
    {
        //        [self.myQueue setSuspended:NO];
        [self drawPointAnimate];
    }
}

- (void)pauseOrContinueDrawing
{
    _isPause = !_isPause;
    if (!_isPause)
    {
        //        [self.myQueue setSuspended:NO];
        [self drawPointAnimate];
    }
}

- (void)setCompletePlayDrawing:(completePlayDrawing)block
{
    self.completePlayBlock = block;
}

- (void)changeColor:(UIView*)bgView
{
    UIColor * color;
    UIColor * actualLineColor;
    if (ise)
    {
        self.lineColor = _lastColor;
        color = bgView.backgroundColor;
        bgView.backgroundColor = _lastColor;
        _lastColor = color;
        actualLineColor = _lastColor;
    }
    else
    {
        color = self.lineColor;
        self.lineColor = bgView.backgroundColor;
        bgView.backgroundColor = color;
        actualLineColor = self.lineColor;
    }
    self.bgColor = bgView.backgroundColor;
    for (TSHPath* path in self.localPaths)
    {
        if(path.isEraser)
        {
            path.pathColor = [UIColor clearColor];
        }
        else
            path.pathColor = actualLineColor;
    }
    //    __weak __typeof(self) weakSelf = self;
    ////    [self.myQueue addOperationWithBlock:^{
    //        NSData* data = [weakSelf getCurrentDrawingJsonFile];
    //        NSString * str = [data mj_JSONString];
    //        NSArray * arr = [str mj_JSONObject];
    //        NSMutableArray* muArr = [NSMutableArray new];
    for (TSHDrawModel *model in self.needSaveModels)
    {
        model.backgroundColor = [self.bgColor toColorString];
        model.paintColor = [actualLineColor toColorString];
    }
    
    //        [weakSelf writeAllModelToJsonFileWith:muArr];
    //    }];
    
    //    for (TSHDrawModel * model in self.needSaveModels)
    //    {
    //        model.paintColor = [actualLineColor toColorString];
    //        model.backgroundColor = [bgView.backgroundColor toColorString];
    //    }
    [self drawAllPath];
}

- (void)eraser
{        //保存上次绘制状态
    
    _lastColor = self.lineColor;
    
    _lastLineWidth = self.lineWidth;
    
    //设置橡皮擦属性
    self.lineColor = [UIColor clearColor];
    self.lineWidth = EraserLineWidth/_zoomScale;
    ise = YES;
}

- (void)cancleEraser
{
    ise = NO;
    self.lineColor = _lastColor;
    self.lineWidth = _lastLineWidth;
}

- (BOOL)isExistActualPath
{
    return isExitDrawModel;
}

- (UIImage *)getSignatureWith:(NSString *)userName
{
    UIImage *signature = [UIImage imageNamed:@"signature"];
    CGSize strSize = [userName stringSizeWithFont:[UIFont systemFontOfSize:11]];
    return [signature watermarkWithName:userName andTextRect:CGRectMake(0, 0, strSize.width, strSize.height) font:11 textColor:[UIColor blackColor]];
}

- (void)saveCurrentImageToAlbumWithUserName:(NSString *)userName
{
    [MobClick beginLogPageView:@"saveImageToAlbum"];
    
    UIImage *signImg = [self getSignatureWith:userName];
    UIImage *shareImg = [self getCurrentImage];
    UIImageWriteToSavedPhotosAlbum([shareImg imageWithWaterMask:signImg inRect:CGRectMake(shareImg.size.width - signImg.size.width-8, shareImg.size.height - signImg.size.height, signImg.size.width, signImg.size.height)], nil, nil, nil);
}

- (UIImage *)getCurrentImage
{
    
    //UIGraphicsBeginImageContext(self.bounds.size);
    
    //    CGFloat scale ;
    //    if (isiPad)
    //    {
    //        scale = [UIScreen mainScreen].scale;
    //    }
    //    else
    //    {
    //        scale = 3.5;
    //    }
    //scale = 4.0;
    
    //UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 1.0);
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, [UIScreen mainScreen].scale);
    //UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, scale);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [self.superview.layer renderInContext:context];
    
    UIImage *getImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();

    return getImage;
}

- (NSURL*)getCurrentJsonFileUrl
{
    NSURL* url = [NSURL URLWithString:[self getJsonFilePath]];
    return url;
}

- (BOOL)saveDrawContentToLocal:(TSHDrawCotent*)drawCt chanel:(TSHChannel*)chanel forkImg:(UIImage*)forkImage topic:(TSHTopic*)topic isASNewDraft:(BOOL)isNewDraft tempDraftImage:(UIImage *)tempImg drawStyle:(NSNumber *)drawStyle boardType:(NSNumber *)type
{
    TSHDrawCotent* draw = [[TSHDrawCotent alloc]init];
    draw.boardType = type;
    draw.albumBgimg = self.bgImg;
    draw.draftImg = tempImg?tempImg:[self getCurrentImage];
    draw.beforeDrawing = drawCt;
    draw.channel = chanel;
    draw.forkImg = forkImage;
    draw.topic = topic;
    draw.topic_id = topic.ID;
    draw.style = drawStyle;
    //    NSData* data = [self getCurrentDrawingJsonFile];
    //    NSString * str = [data mj_JSONString];
    //    NSArray * arr = [str mj_JSONObject];
    draw.drawModels = self.needSaveModels;
    NSString *name;
    NSString *uid = [UserManager sharedInstance].loginUser.uid;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *dataDictionary;
    NSString *filePath = [self getJsonFilePath:[NSString stringWithFormat:@"Draft/%@/%@", uid, DRAW_JSON_LIST_PATH]];
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"YYYY年MM月dd"];
    NSString * currentDateStringYMd = [dateFormatter stringFromDate:currentDate];
    [dateFormatter setDateFormat:@"HH:mm"];
    NSString * currentDateStringHm = [dateFormatter stringFromDate:currentDate];
    
    if(![fileManager fileExistsAtPath:filePath])
    {
        NSDictionary * dataDic = @{
                                   @"data":@[@{
                                                 @"uid":uid,
                                                 @"isShow":@(1),
                                                 @"name":@"0",
                                                 @"timeYMd":currentDateStringYMd,
                                                 @"timeHm":currentDateStringHm}]};
        if ([dataDic writeToFile:filePath atomically:YES])
        {
            NSLog(@"yes");
        }
        else
            NSLog(@"no");
        name = @"0";
    }
    else
    {
        dataDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        NSMutableArray * arr = [NSMutableArray arrayWithArray:dataDictionary[@"data"]];
        if (isReadLocalData && !isNewDraft)
        {
            int  index = 0;
            for (NSDictionary*dic  in arr)
            {
                NSNumber* isShow = dic[@"isShow"];
                if(isShow.boolValue)
                {
                    name = dic[@"name"];
                    break;
                }
                index++;
            }
            [arr removeObjectAtIndex:index];
        }
        else
        {
            for (NSDictionary*dic  in arr)
            {
                [dic setValue:@(0) forKey:@"isShow"];
            }
            name = [NSString stringWithFormat:@"%ld",(unsigned long)arr.count];
        }
        [arr addObject:@{
                         @"uid":uid,
                         @"isShow":@(1),
                         @"name":name,
                         @"timeYMd":currentDateStringYMd,
                         @"timeHm":currentDateStringHm}];
        [dataDictionary setValue:arr forKey:@"data"];
        [dataDictionary writeToFile:filePath atomically:YES];
    }
    
    NSString *file = [self getJsonFilePath:[NSString stringWithFormat:@"%@%@/%@",DRAFT_DRAW_JSON_PATH, uid, name]];
    [[NSFileManager defaultManager]removeItemAtPath:file error:nil];
    return [NSKeyedArchiver archiveRootObject:draw toFile:file];
}

- (void)writeAllModelToJsonFileByOldRule
{
    NSFileHandle *fileHandle;
    int flag = 0;
    for (TSHDrawModel * model in self.needSaveModels)
    {
        if (flag==0)
        {
            NSString *json = [NSString stringWithFormat:@"%@%@", @"[", [model getOldRuleDescription]];
            NSData *jsonData = [json mj_JSONData];
            [jsonData writeToFile:UPLOAD_DRAW_JSON_OldRulePATH atomically:YES];
            
            fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:UPLOAD_DRAW_JSON_OldRulePATH];
        }
        else
        {
            [fileHandle seekToEndOfFile];
            NSString *jsonModel = [NSString stringWithFormat:@"%@%@", @",", [model getOldRuleDescription]];
            NSData *stringData  = [jsonModel dataUsingEncoding:NSUTF8StringEncoding];
            
            [fileHandle writeData:stringData];
        }
        
        flag++;
    }
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[@"]" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (NSData*)getCurrentDrawingJsonFile
{
    [self getJsonFilePath];
    [[NSFileManager defaultManager] removeItemAtPath:UPLOAD_DRAW_JSON_OldRulePATH error:nil];
//    [self writeAllModelToJsonFileByOldRule];
    [self writeAllModelToJsonFileByRemoveModelWith:self.needSaveModels];
//    [self writeAllModelToJsonFileWith:self.needSaveModels];
//    + (id)dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;

//    NSData *data=[NSData dataWithContentsOfFile:[self getJsonFilePath]];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:[self getJsonFilePath] options:NSDataReadingMappedIfSafe error:&error];
    if (error)
    {
        NSLog(@"json error:%@", data);
    }
    return data;
}

- (NSArray *)getNeedSaveModels
{
    return self.needSaveModels;
}

- (NSData *)getCompleteForkDrawingJsonWith:(NSString *)jsonUrl
{
    NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:jsonUrl]];
    if (jsonData!=nil)
    {
        NSString *json = [jsonData mj_JSONString];
        NSString *jsonLocal = [[self getCurrentDrawingJsonFile] mj_JSONString];
        NSString *mergeJson = [NSString stringWithFormat:@"%@,%@",[json substringToIndex:(json.length - 1)],[jsonLocal substringFromIndex:1]];
        NSString *filePath = [self getJsonFilePath:UPLOAD_DRAW_FULL_JSON_PATH];
        
        [mergeJson writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        //        for (TSHDrawModel * model in arrMu)
        //        {
        //            NSString* jsonStr = [[NSData dataWithContentsOfFile:filePath] mj_JSONString];
        //            if ([jsonStr hasSuffix:@"]"])
        //            {
        //                jsonStr = [jsonStr substringToIndex:jsonStr.length - 1];
        //            }
        //            if (jsonStr == nil)
        //            {
        //                jsonStr = [model description];
        //            }
        //            else
        //            {
        //                jsonStr = [NSString stringWithFormat:@"%@,%@", jsonStr, [model description]];
        //            }
        //            NSData *jsonData = [self formatData:jsonStr];
        //            [jsonData writeToFile:filePath atomically:YES];
        //        }
        NSData *completeData = [NSData dataWithContentsOfFile:filePath];
        return completeData;
    }
    else
        return nil;
}

- (NSString*)getCurrentDrawingPathJson
{
    for (TSHDrawModel * model in self.needSaveModels)
    {
        [self pointWriteToFile:model];
    }
    return [self readJsonFile];
}

//- (void)drawingStatus:(drawStatusBlock)stautsBlock
//{
//    self.statusBlock = stautsBlock;
//}

- (void)getChangeBoardImage:(boardImageBlock)boardImage
{
    self.boardImage = boardImage;
}

#pragma mark -Touch Drawing
- (void)drawRect:(CGRect)rect
{
    [self.cachedImage drawInRect:self.bounds];
    
    //    CGContextRef ctx = UIGraphicsGetCurrentContext();
    //    UIGraphicsPushContext(ctx);
    //    CGContextSetShouldAntialias(ctx, YES);
    //    CGContextSetAllowsAntialiasing(ctx, true);
    //    [self.bezierPath drawPath];
    
    //    UIGraphicsPopContext();
}

- (UIImage *)drawAllPathsImageWithSize:(CGSize)size backgroundImage:(UIImage *)backgroundImage
{
    CGFloat scale = size.width / CGRectGetWidth(self.bounds);
    
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, scale);
    
    [backgroundImage drawInRect:CGRectMake(0.f, 0.f, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))];
    
    [self drawAllPath];
    
    UIImage *drawnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [UIImage imageWithCGImage:drawnImage.CGImage
                               scale:1.f
                         orientation:drawnImage.imageOrientation];
}

- (void)drawAllPath
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kScreen_Width, kScreen_Width), NO, [UIScreen mainScreen].scale);
    
    for (TSHPath *path in self.localPaths)
    {
        [path drawPath];
    }
    self.cachedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self setNeedsDisplay];
}

- (CGRect)brushRectForPoint:(CGPoint)point
{
    return CGRectMake(point.x - self.lineWidth*0.5, point.y - self.lineWidth*0.5, self.lineWidth, self.lineWidth);
}

- (void)drawBitmap
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    if (self.cachedImage) {
        [self.cachedImage drawAtPoint:CGPointZero];
    }
    [self.bezierPath drawPath];
    //    if (self.pointsArray.count == 1) {
    //        TSHDrawPoint *touchPoint = [self.localTempPoints firstObject];
    //        [self.bezierPath.pathColor setFill];
    //        [TSHPath drawBezierPoint:CGPointMake(touchPoint.x, touchPoint.x)
    //                                 withWidth:self.lineWidth];
    //    }
    self.bezierPath = nil;
    self.cachedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self setNeedsDisplay];
}

- (void)zoomEnd
{
    //    if (self.localTempPoints.count>0)
    //    {
    //        CGFloat interval = CFAbsoluteTimeGetCurrent() - _lastInterval;
    //        TSHDrawModel *model = [self.needSaveModels lastObject];
    //        model.pointList = [NSArray arrayWithArray:self.localTempPoints];
    //        model.totalTime = interval;
    //        //        self.remoteTempModel = model;
    //        //        __weak __typeof(self) weakSelf = self;
    //        ////        [self.myQueue addOperationWithBlock:^{
    //        //            [weakSelf pointWriteToFile:model];
    //        ////        }];
    //        //
    //        [self.localTempPoints removeAllObjects];
    //    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    UIGestureRecognizer* ges = [touch.gestureRecognizers lastObject];
    if (ges.numberOfTouches<2)
    {
        [self.localTempPoints removeAllObjects];
        //        NSLog(@"begin in");
        CGPoint point = [touch locationInView:self] ;
        TSHPath *path = [TSHPath pathToPoint:point pathWidth:self.lineWidth];
        path.pathColor = self.lineColor;
        path.startPoint = point;
        path.isEraser = ise;
        [self.localPaths addObject:path];
        TSHDrawPoint * drawPoint = [TSHDrawPoint drawPoint:point withInterval:0];
        [drawPoint setControllPoint1:point ControllPoint2:point];
        [self.localTempPoints addObject:drawPoint];
        [self.tempPoints removeAllObjects];
        [self.tempPoints addObject:drawPoint];
        _lastInterval = CFAbsoluteTimeGetCurrent();
        TSHDrawModel *model = [[TSHDrawModel alloc] init];
//        model.action = @(ActionPlaying);
        model.paintColor = [self.lineColor toColorString];
        model.paintSize = @(self.lineWidth);
        model.isEraser = [NSNumber numberWithBool:ise];
        model.pointList = [NSArray arrayWithArray:self.localTempPoints];
        model.backgroundColor = [self.bgColor toColorString];
        model.width = @(self.width);
        model.hight = @(self.height);
        model.background = self.bgImageStr;
        [self.needSaveModels addObject:model];
        
        self.pointsCounter = 0;
        //清空
        //        self.bezierPath = path;
        //        [self drawBitmap];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    UIGestureRecognizer* ges = [touch.gestureRecognizers lastObject];
    if (ges.numberOfTouches<2)
    {
        
        //        NSLog(@"move in");
        if (self.pointsCounter == 0 && _isExitBackPath)
        {
            [self.localTempPath removeAllObjects];
            [self.remoteModels removeAllObjects];
            _isExitBackPath = NO;
        }
        self.pointsCounter++;
        CGPoint point = [touch locationInView:self] ;
        //    NSLog(@"move:%f,begany:%f",point.x,point.y);
        
        TSHDrawPoint * drawPoint = [TSHDrawPoint drawPoint:point withInterval:0];
        //    [self.localTempPoints addObject:drawPoint];
        [self.tempPoints addObject:drawPoint];
        if (self.pointsCounter==4)
        {
            TSHPath *path = [self.localPaths lastObject];
            //        TSHDrawPoint * start_Point = self.tempPoints[0];//i-1
            TSHDrawPoint *p1 = self.tempPoints[1];//i
            TSHDrawPoint *p2 = self.tempPoints[2];//i+1
            TSHDrawPoint *end_Point = self.tempPoints[3];//i+2
            TSHDrawPoint *p4 = self.tempPoints[4];
            //PA:三次曲线已知点－>>求控制点
            //                path.startPoint = CGPointMake(start_Point.x , start_Point.y);
            //                path.endPoint = CGPointMake(end_Point.x, end_Point.y);
            //                path.controlPoint1 = CGPointMake(p1.x+(1.0/3.0)*(p2.x-start_Point.x) , p1.y+(1.0/3.0)*(p2.y-start_Point.y));
            //                path.controlPoint2 = CGPointMake(p2.x+(1.0/3.0)*(end_Point.x-p1.x) , p2.y+(1.0/3.0)*(end_Point.y-p1.y));
            //PB:三次曲线已知点－>>求终点
            end_Point.x = (p2.x + p4.x)*0.5;
            end_Point.y = (p2.y + p4.y)*0.5;
            //        path.startPoint = CGPointMake(start_Point.x , start_Point.y);
            path.endPoint = CGPointMake(end_Point.x, end_Point.y);
            path.controlPoint1 = CGPointMake(p1.x, p1.y);
            path.controlPoint2 = CGPointMake(p2.x, p2.y);
            TSHDrawPoint* needSave_Point = [TSHDrawPoint drawPoint:path.endPoint withInterval:0];
            [needSave_Point setControllPoint1:path.controlPoint1 ControllPoint2:path.controlPoint2];
            [self.localTempPoints addObject:needSave_Point];
            [path drawPathLine:pathDrawTypeMove];
            self.tempPoints[0] = self.tempPoints[3];
            self.tempPoints[1] = self.tempPoints[4];
            self.bezierPath = path;
            TSHDrawModel * model = [self.needSaveModels lastObject];
            model.pointList = [NSArray arrayWithArray:self.localTempPoints];
            [self drawBitmap];
            
            self.pointsCounter = 1;
            //        [self.localTempPoints removeObjectAtIndex:0];
            //                self.localTempPoints[0] = end_Point;
            [self.tempPoints removeLastObject];
            [self.tempPoints removeLastObject];
            [self.tempPoints removeLastObject];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    UIGestureRecognizer* ges = [touch.gestureRecognizers lastObject];
    if (ges.numberOfTouches<2)
    {
        //        NSLog(@"end in");
        isExitDrawModel++;
        CGPoint point = [touch locationInView:self] ;
        CGFloat interval = CFAbsoluteTimeGetCurrent() - _lastInterval;
        TSHDrawPoint* d_point = [TSHDrawPoint drawPoint:point withInterval:interval];
        [d_point setControllPoint1:point ControllPoint2:point];
        [self.localTempPoints addObject:d_point];
        TSHDrawModel *model = [self.needSaveModels lastObject];
        model.pointList = [NSArray arrayWithArray:self.localTempPoints];
        model.totalTime = interval;
        //        self.remoteTempModel = model;
        //        if (self.pointsCounter==0)
        //        {
        //            TSHPath *path = [TSHPath pathToPoint:point pathWidth:self.lineWidth];
        //            path.pathColor = self.lineColor;
        //            path.startPoint = point;
        //            path.isEraser = ise;
        //            [self.localPaths addObject:path];
        //            TSHDrawPoint * drawPoint = [TSHDrawPoint drawPoint:point withInterval:0];
        //            [drawPoint setControllPoint1:point ControllPoint2:point];
        //            [self.localTempPoints addObject:drawPoint];
        //            model.pointList = [NSArray arrayWithArray:self.localTempPoints];
        //            [path drawPathLine:pathDrawTypeStart];
        //        }
        TSHPath *path = [self.localPaths lastObject];
        path.endPoint = point;
        [path drawPathLine:pathDrawTypeEnd];
        //        if (self.statusBlock)
        //        {
        //            self.statusBlock(TSHDrawingStatusEnd,model);
        //        }
        //        __weak __typeof(self) weakSelf = self;
        //        [self.myQueue addOperationWithBlock:^{
        //            [weakSelf pointWriteToFile:model];
        //        }];
        //        [self pointWriteToFile:model];
        self.bezierPath = path;
        [self.localTempPoints removeAllObjects];
        [self drawBitmap];
        [[NSNotificationCenter defaultCenter] postNotificationName:Action_RefreshThumbnail object:nil];
    }
}

#pragma mark - WriteToFile

- (NSString*)getJsonFilePath:(NSString*)fileName
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *createDir = [NSString stringWithFormat:@"%@/Cache/Upload", pathDocuments];
    NSString *createDirDraft = [NSString stringWithFormat:@"%@/Cache/Draft/%@/", pathDocuments,[UserManager sharedInstance].loginUser.uid];
    if (![[NSFileManager defaultManager] fileExistsAtPath:createDir])
    {
        [fileManager createDirectoryAtPath:createDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:createDirDraft])
    {
        NSError *error;
        if (![fileManager createDirectoryAtPath:createDirDraft withIntermediateDirectories:YES attributes:nil error:&error])
        {
            NSLog(@"%@",error.description);
        }
    }
    NSString *jsonPath=[DOCUMENTPATH stringByAppendingPathComponent:[NSString stringWithFormat:@"Cache/%@",fileName]];
    return jsonPath;
}

- (NSString*)getJsonFilePath
{
    return [self getJsonFilePath:UPLOAD_DRAW_JSON_PATH];
}

- (NSData *)formatData:(NSString *)jsonStr
{
    if (![jsonStr hasPrefix:@"["]) {
        jsonStr = [NSString stringWithFormat:@"[%@", jsonStr];
    };
    if (![jsonStr hasSuffix:@"]"]) {
        jsonStr = [NSString stringWithFormat:@"%@]", jsonStr];
    };
    return [jsonStr mj_JSONData];
}

- (void)writeAllModelToJsonFileByRemoveModelWith:(NSMutableArray*)arr
{
    [self removeLocalHistoryJsonFile];
    NSFileHandle *fileHandle;
    int flag = 0;

    for (int i=0; i<arr.count; i=0)
    {
        TSHDrawModel *model = arr.firstObject;
        model.alpha = self.bgAlpha;
        if (flag==0)
        {
            NSString *json = [NSString stringWithFormat:@"%@%@", @"[", model.description];
            NSData *jsonData = [json mj_JSONData];
            [jsonData writeToFile:[self getJsonFilePath] atomically:YES];
            
            fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self getJsonFilePath]];
        }
        else
        {
            [fileHandle seekToEndOfFile];
            NSString *jsonModel = [NSString stringWithFormat:@"%@%@", @",", model.description];
            NSData* stringData  = [jsonModel dataUsingEncoding:NSUTF8StringEncoding];
            
            [fileHandle writeData:stringData];
        }
        
        flag++;
        [arr removeObjectAtIndex:0];
    }
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[@"]" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (void)writeAllModelToJsonFileWith:(NSArray*)arr
{
    [self removeLocalHistoryJsonFile];
    NSFileHandle *fileHandle;
    int flag = 0;
    for (TSHDrawModel * model in arr)
    {
        if (flag==0)
        {
            NSString *json = [NSString stringWithFormat:@"%@%@", @"[", model.description];
            NSData *jsonData = [json mj_JSONData];
            [jsonData writeToFile:[self getJsonFilePath] atomically:YES];

            fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self getJsonFilePath]];
        }
        else
        {
            [fileHandle seekToEndOfFile];
            NSString *jsonModel = [NSString stringWithFormat:@"%@%@", @",", model.description];
            NSData* stringData  = [jsonModel dataUsingEncoding:NSUTF8StringEncoding];

            [fileHandle writeData:stringData];
        }
        
        flag++;
    }
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[@"]" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (void)pointWriteToFile:(TSHDrawModel *)model
{
    NSString* jsonStr = [self readJsonFile];
    
    if ([jsonStr hasSuffix:@"]"])
    {
        jsonStr = [jsonStr substringToIndex:jsonStr.length - 1];
    }
    if (jsonStr == nil)
    {
        jsonStr = [model description];
    }
    else
    {
        jsonStr = [NSString stringWithFormat:@"%@,%@", jsonStr, [model description]];
    }
    NSData *jsonData = [self formatData:jsonStr];
    [jsonData writeToFile:[self getJsonFilePath] atomically:YES];
    
//    NSString* jsonStr = [self readJsonFile];
//
//    if ([jsonStr hasSuffix:@"]"])
//    {
//        jsonStr = [jsonStr substringToIndex:jsonStr.length - 1];
//    }
//    if (jsonStr == nil)
//    {
//        jsonStr = [model description];
//    }
//    else
//    {
//        jsonStr = [NSString stringWithFormat:@"%@,%@", jsonStr, [model description]];
//    }
//    NSData *jsonData = [self formatData:jsonStr];
//    [jsonData writeToFile:[self getJsonFilePath] atomically:YES];
}

- (NSString *)readJsonFile
{
    //    diskCache set
    
    NSData *data=[NSData dataWithContentsOfFile:[self getJsonFilePath]];
    
    return [data mj_JSONString];
}

- (void)removeLocalHistoryJsonFile
{
    NSFileManager *file = [NSFileManager defaultManager];
    
    [file removeItemAtPath:[self getJsonFilePath] error:nil];
}

#pragma mark 绘画接收到到数据
- (void)userAction:(NSInteger)action
{
    switch (action) {
        case ActionChangeBackground:    // 更换背景
            
            break;
        case ActionPlaying:     // 绘画
            [self drawPlayBack];
            break;
        case ActionGoback:      // 撤销
            
            break;
        case ActionGoforward:   // 前进
            
            break;
        case ActionClearAll:    // 清屏
            
            break;
        default:
            break;
    }
}

- (void)loadLocalDataModel
{
    // 读取本地数据
    NSString *jsonStr = [self readJsonFile];
    NSArray *arr = [jsonStr mj_JSONObject];
    for (NSDictionary *dic in arr)
    {
        TSHDrawModel *model = [TSHDrawModel mj_objectWithKeyValues:dic];
        [self.remoteModels addObject:model];
    }
}

// 回放
- (void)drawPlayBack
{
    self.userInteractionEnabled = NO;
    //     删除现有轨迹
    //    self.remoteModels = [NSMutableArray arrayWithCapacity:0];
    
    [self.localPaths removeAllObjects];
    [self setNeedsDisplay];
    //    [self loadLocalDataModel];
    
    self.remoteModels = [NSMutableArray arrayWithArray:self.needSaveModels];
    TSHDrawModel *model = [self.remoteModels firstObject];
    if (model)
    {
        [self drawWithPoints:model];
    }
}

//- (TSHCAShapeLayer*)drawLayer
//{
//    if (!_drawLayer) {
//        TSHCAShapeLayer *layer = [TSHCAShapeLayer layer];
//        layer.frame = CGRectMake(0, 0, self.width, self.height);
//        layer.position = self.center;
//        layer.backgroundColor = [UIColor clearColor].CGColor;
//        layer.fillColor = [UIColor clearColor].CGColor;
//        [self.layer addSublayer:layer];
//
//        _drawLayer = layer;
//    }
//    return _drawLayer;
//}

- (void)sliderValue:(UISlider*)slider
{
    self.layer.timeOffset = slider.value;
}

- (void)drawPlayBackNetSource:(NSArray*)data ID:(NSInteger)ID;
{
    isStop = NO;
    _isPause = NO;
    _totalTime = _lastInterval = 0;
    _drawContenID = ID;
    [self clearAll];
    self.backDrawArr = data;
    //    self.drawLayer.data = data;
    self.remoteModels = [NSMutableArray arrayWithArray:data];
    for (TSHDrawModel* mo in self.remoteModels)
    {
        _totalTime = _totalTime + mo.pointList.count*PerPointsSeconds;
    }
    TSHDrawModel *model = [self.remoteModels firstObject];
    _index = 0;
    CGFloat xp = self.width / model.width.doubleValue ;
    //    CGFloat yp = self.height / model.hight.doubleValue ;
    _xP = xp;
    //    _yP = yp;
    if (model&& !isStop)
    {
        [self drawWithPoints:model];
        //        [self.remoteModels removeObjectAtIndex:0];
    }
}

// 绘画接收到的轨迹
- (BOOL)drawWithPoints:(TSHDrawModel *)model
{
    TSHDrawPoint *point = [model.pointList firstObject];
    CGPoint startPoint = CGPointMake(point.x * _xP,
                                     point.y * _xP);
    
    TSHPath *path = [TSHPath pathToPoint:startPoint pathWidth:model.paintSize.floatValue *_xP];
    
    _lastInterval = _lastInterval + PerPointsSeconds;
    path.pathColor = [UIColor colorWithHexString:model.paintColor];
    path.isEraser = model.isEraser.boolValue;
    if (path.isEraser)
    {
        path.pathColor = [UIColor clearColor];
    }
    if (point)
    {
        NSMutableArray *marray = [NSMutableArray arrayWithArray:model.pointList];
        [marray removeObject:point];
        
        self.remotePoints = marray;
    }
    
    [self.localPaths addObject:path];
    self.bezierPath = path;
    [self readPath:path time:PerPointsSeconds];
    return YES;
}

// 读取轨迹
- (void)readPath:(TSHPath *)path time:(float)time
{
    TSHDrawPoint *point = [self.remotePoints firstObject];
    if (!point)
    {
        _index++;
        if (_index==self.remoteModels.count)
        {
            if (self.completePlayBlock)
            {
                self.completePlayBlock();
            }
        }
        else
        {
            TSHDrawModel *model = [self.remoteModels objectAtIndex:_index];
            if (model)
            {
                [self drawWithPoints:model];
            }
        }
        //        if (model)
        //        {
        //            [self drawWithPoints:model];
        ////            [self.remoteModels removeObjectAtIndex:0];
        //        }
        //        else
        //        {
        //            if (self.completePlayBlock)
        //            {
        //                self.completePlayBlock();
        //            }
        //        }
        return;
    }
    self.remoteTempPath = path;
    self.remoteTempPoint = point;
    [self drawPointAnimate];
}

- (void)drawPointAnimate
{
    if (_isPause||isStop)
    {
        if (isStop)
        {
            _isPause = NO;
        }
    }
    else
    {
        //        __weak __typeof(self) weakSelf = self;
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, PerPointsSeconds), dispatch_get_main_queue(), ^{
        //            [weakSelf delayDraw];
        //        });
        [self performSelector:@selector(delayDraw) withObject:nil afterDelay:0];
    }
}

- (void)delayDraw
{
    if (!isStop)
    {
        TSHDrawPoint * tp = self.remoteTempPoint;
        [self.remoteTempPath.bezierPath addCurveToPoint:CGPointMake(tp.x*_xP, tp.y*_xP) controlPoint1:CGPointMake(tp.controllPoint1x*_xP, tp.controllPoint1y*_xP) controlPoint2:CGPointMake(tp.controllPoint2x*_xP, tp.controllPoint2y*_xP)];
        self.bezierPath = self.remoteTempPath;
        [self drawBitmap];
        
        _lastInterval = _lastInterval + PerPointsSeconds;
        if (self.drawingProgressCb)
        {
            self.drawingProgressCb(_lastInterval/_totalTime,_drawContenID);
        }
        //        [[NSNotificationCenter defaultCenter] postNotificationName:DrawProgressChangeNotification object:@(_lastInterval/_totalTime) userInfo:@{@"id":@(_drawContenID)}];
        
        if (self.remotePoints.count > 0)
        {
            [self.remotePoints removeObjectAtIndex:0];
        }
        [self readPath:self.remoteTempPath time:PerPointsSeconds];
    }
}

- (void)drawThumbnail
{
    [self setNeedsDisplay];
    //    NSData *data = [self getCurrentDrawingJsonFile];
    //    NSString *str = [data mj_JSONString];
    //    NSArray *arr = [str mj_JSONObject];
    //    NSMutableArray * muArr = [TSHDrawModel mj_objectArrayWithKeyValuesArray:arr];
    //    [self.localPaths removeAllObjects];
    //    [self setNeedsDisplay];
    //    for (TSHDrawModel *model in muArr)
    //    {
    ////        self.remoteTempModel = model;
    //        self.remotePoints = [NSMutableArray arrayWithArray:model.pointList];
    //        for (int j=0; j< model.pointList.count; j++)
    //        {
    //            TSHDrawPoint *point = model.pointList[j];
    //            if (j==0)
    //            {
    //                CGFloat xp = self.width / model.width.floatValue ;
    //                CGFloat yp = self.height / model.hight.floatValue ;
    //                _xP = xp;
    //                _yP = yp;
    //
    //                CGPoint startPoint = CGPointMake(point.x * _xP,point.y * _yP);
    //                TSHPath *path = [TSHPath pathToPoint:startPoint pathWidth:model.paintSize.floatValue * _xP];
    //
    //                path.pathColor = [UIColor colorWithHexString:model.paintColor];
    //                path.isEraser = model.isEraser.boolValue;
    //                if (path.isEraser)
    //                {
    //                    path.pathColor = [UIColor clearColor];
    //                }
    //                [self.localPaths addObject:path];
    //            }
    //            else
    //            {
    //                TSHPath *path = [self.localPaths lastObject];
    //                path.endPoint = CGPointMake(point.x * _xP , point.y * _yP);
    //                path.controlPoint1 = CGPointMake(point.controllPoint1x * _xP, point.controllPoint1y * _yP) ;
    //                path.controlPoint2 = CGPointMake(point.controllPoint2x * _xP, point.controllPoint2y * _yP) ;
    //                [path drawPathLine:pathDrawTypeMove];
    //                [self setNeedsDisplay];
    //            }
    //        }
    //    }
}

- (void)drawLocalData
{
    [self.localPaths removeAllObjects];
    
    for (TSHDrawModel *model in self.models)
    {
        //        self.remoteTempModel = model;
        self.remotePoints = [NSMutableArray arrayWithArray:model.pointList];
        for (int j=0; j< model.pointList.count; j++)
        {
            TSHDrawPoint *point =  model.pointList[j];
            if (j==0)
            {
                CGPoint startPoint = CGPointMake(point.x,point.y);
                TSHPath *path = [TSHPath pathToPoint:startPoint pathWidth:model.paintSize.floatValue];
                
                path.pathColor = [UIColor colorWithHexString:model.paintColor];
                path.isEraser = model.isEraser.boolValue;
                if (path.isEraser)
                {
                    path.pathColor = [UIColor clearColor];
                }
                [self.localPaths addObject:path];
            }
            else
            {
                TSHPath *path = [self.localPaths lastObject];
                path.endPoint = CGPointMake(point.x, point.y);
                path.controlPoint1 = CGPointMake(point.controllPoint1x, point.controllPoint1y) ;
                path.controlPoint2 = CGPointMake(point.controllPoint2x, point.controllPoint2y) ;
                [path drawPathLine:pathDrawTypeMove];
            }
        }
    }
    self.needSaveModels = [NSMutableArray arrayWithArray:self.models];
    [self drawAllPath];
    //    [self writeAllModelToJsonFileWith:self.models];
}

#pragma mark - 访问器

- (void)setModels:(NSArray *)models
{
    _models = models;
    isReadLocalData = YES;
    [self drawLocalData];
}

- (NSMutableArray *)remoteTempModels
{
    if (!_remoteTempModels)
    {
        _remoteTempModels = [NSMutableArray new];
    }
    return _remoteTempModels;
}

//- (NSOperationQueue *)myQueue
//{
//    if (!_myQueue) {
//        _myQueue = [[NSOperationQueue alloc] init];
//        _myQueue.maxConcurrentOperationCount = 1;
//    }
//    return _myQueue;
//}

- (NSMutableArray *)localPaths
{
    if (!_localPaths) {
        _localPaths = [NSMutableArray array];
    }
    return _localPaths;
}

- (NSMutableArray *)localTempPoints
{
    if (!_localTempPoints) {
        _localTempPoints = [NSMutableArray array];
    }
    return _localTempPoints;
}

- (NSMutableArray *)tempPoints
{
    if (!_tempPoints) {
        _tempPoints = [NSMutableArray array];
    }
    return _tempPoints;
}

- (NSMutableArray *)localTempPath
{
    if (!_localTempPath) {
        _localTempPath = [NSMutableArray array];
    }
    return _localTempPath;
}

- (NSMutableArray *)remotePaths
{
    if (!_remotePaths) {
        _remotePaths = [NSMutableArray array];
    }
    return _remotePaths;
}

- (NSMutableArray *)remotePoints
{
    if (!_remotePoints) {
        _remotePoints = [NSMutableArray array];
    }
    return _remotePoints;
}

- (NSMutableArray *)remoteTempPaths
{
    if (!_remoteTempPaths) {
        _remoteTempPaths = [NSMutableArray array];
    }
    return _remoteTempPaths;
}

- (NSMutableArray *)needSaveModels
{
    if (!_needSaveModels) {
        _needSaveModels = [NSMutableArray array];
    }
    return _needSaveModels;
}

- (void)setLineColor:(UIColor *)lineColor
{
    if (ise) {
        _lastColor = lineColor;
        return;
    }
    _lineColor = lineColor;
}

//- (void)setLineWidth:(CGFloat)lineWidth
//{
//    _lineWidth = lineWidth;
//    //    if (ise)
//    //    {
//    //        _lastLineWidth = lineWidth * 0.4;
//    //    }
//}

- (void)dealloc
{
    ise = NO;
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:ImageBoardNotification object:nil];
    //    [[NSNotificationCenter defaultCenter] removeObserver:self name:SliderValueChangeNotification object:nil];
}

@end

#pragma mark - Path

@implementation TSHPath

//- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
//{
//    if (self = [super init])
//    {
//        self.pathColor = [aDecoder decodeObjectForKey:kactivityNum]
//    }
//    return self;
//}
//
//- (void)encodeWithCoder:(NSCoder *)aCoder
//{
//
//}

+ (instancetype)pathToPoint:(CGPoint)beginPoint pathWidth:(CGFloat)pathWidth
{
    TSHPath *path = [[TSHPath alloc] init];
    path.isEraser = ise;
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    
    bezierPath.lineCapStyle = kCGLineCapRound;
    bezierPath.lineJoinStyle = kCGLineJoinRound;
    bezierPath.lineWidth = pathWidth;
    //    bezierPath.flatness = 0.01;
    [bezierPath moveToPoint:beginPoint];
    path.bezierPath = bezierPath;
    return path;
}

+ (void)drawBezierPoint:(CGPoint)point withWidth:(CGFloat)width
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    
    CGContextFillEllipseInRect(context, CGRectInset(CGRectMake(point.x, point.y, 0.f, 0.f), -width / 2.f, -width / 2.f));
}

- (void)drawPathLine:(pathDrawType)type
{
    switch (type) {
        case pathDrawTypeStart:
            [self.bezierPath addCurveToPoint:self.startPoint controlPoint1:self.startPoint controlPoint2:self.startPoint];
            break;
        case pathDrawTypeMove:
            [self.bezierPath addCurveToPoint:self.endPoint controlPoint1:self.controlPoint1 controlPoint2:self.controlPoint2];
            break;
        case pathDrawTypeEnd:
            [self.bezierPath addCurveToPoint:self.endPoint controlPoint1:self.endPoint controlPoint2:self.endPoint];
            break;
        default:
            break;
    }
}

- (void)pathLineToPoint:(CGPoint)endPoint startPoint:(CGPoint)startPoint
{
    [self.bezierPath addCurveToPoint:self.endPoint controlPoint1:self.controlPoint1 controlPoint2:self.controlPoint2];
}

- (void)drawPath
{
    [self.pathColor set];
    if (self.isEraser)
    {
        [self.bezierPath strokeWithBlendMode:kCGBlendModeClear alpha:1.0];
    }
    
    [self.bezierPath stroke];
}
@end

#pragma mark TSHCAShapeLayer
//@implementation TSHCAShapeLayer
//- (NSMutableArray *)paths
//{
//    if (!_paths)
//    {
//        _paths = [NSMutableArray new];
//    }
//    return _paths;
//}
//
//- (void)setData:(NSArray *)data
//{
//    _data = data;
//    CGFloat totalTime = data.count*0.5;
//    int count = 0 ;
//    for (TSHDrawModel* model in self.data)
//    {
//        self.lineWidth = model.paintSize.integerValue;
//        
//        CGFloat xp = self.bounds.size.width / model.width.floatValue ;
//        CGFloat yp = self.bounds.size.height / model.hight.floatValue ;
//        
//        TSHDrawPoint *point = [model.pointList firstObject];
//        CGPoint startPoint = CGPointMake(point.x*xp,point.y*yp );
//        TSHPath *path = [TSHPath pathToPoint:startPoint pathWidth:model.paintSize.floatValue];
//        path.isEraser = model.isEraser.boolValue;
//        if (count==0)
//        {
//            self.myBezierPath = path.bezierPath;
//        }
//        [self.paths addObject:path];
//        path.pathColor = [UIColor colorWithHexString:model.paintColor];
//        self.strokeColor = path.pathColor.CGColor;
//        //        self.lineWidth = path.bezierPath.lineWidth;
//        //        if (path.isEraser)
//        //        {
//        //            self.strokeColor = [UIColor clearColor].CGColor;
//        //        }
//        
//        for (int i = 1; i<model.pointList.count; i++)
//        {
//            TSHDrawPoint *tp = model.pointList[i];
//            
//            [path.bezierPath addCurveToPoint:CGPointMake(tp.x*xp, tp.y*yp) controlPoint1:CGPointMake(tp.controllPoint1x*xp, tp.controllPoint1y*yp) controlPoint2:CGPointMake(tp.controllPoint2x*xp, tp.controllPoint2y*yp)];
//        }
//        if (count!=0)
//        {
//            [self.myBezierPath appendPath:path.bezierPath];
//        }
//        count=1;
//    }
//    
//    self.lineCap = @"round";
//    self.lineJoin = @"round";
//    //    self.path = self.myBezierPath.CGPath;
//    
//    //    self.strokeColor = path.pathColor.CGColor;
//    //    self.lineWidth = path.bezierPath.lineWidth;
//    //    if (path.isEraser)
//    //    {
//    //        self.strokeColor = [UIColor clearColor].CGColor;
//    //    }
//    
//    CAKeyframeAnimation * basic = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
//    basic.removedOnCompletion = NO;
//    //    basic.fromValue = @(0);
//    //    basic.toValue = @(1);
//    basic.path = self.myBezierPath.CGPath;
//    basic.duration = totalTime;
//    basic.fillMode = kCAFillModeForwards;
//    basic.delegate = self;
//    [self addAnimation:basic forKey:@"strokeAnimation"];
//}
//
//- (void)display
//{
//    
//}
//
//- (void)createBasicAnimation
//{
//    TSHPath * path = self.paths.firstObject;
//    self.path = path.bezierPath.CGPath;
//    
//    self.strokeColor = path.pathColor.CGColor;
//    self.lineWidth = path.bezierPath.lineWidth;
//    if (path.isEraser)
//    {
//        self.strokeColor = [UIColor clearColor].CGColor;
//    }
//    CABasicAnimation * basic = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
//    basic.removedOnCompletion = NO;
//    basic.fromValue = @(0);
//    basic.toValue = @(1);
//    basic.duration = 0.5;
//    basic.fillMode = kCAFillModeForwards;
//    //    basic.delegate = self;
//    [self addAnimation:basic forKey:@"strokeAnimation"];
//}
//
//- (void)animationDidStart:(CAAnimation *)anim
//{
//    //    if (self.paths.count>0)
//    //    {
//    //        [self.paths removeObjectAtIndex:0];
//    //    }
//}
//
//- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
//{
//    //    if (flag)
//    //    {
//    //        if (self.paths.count>0)
//    //        {
//    //            [self createBasicAnimation];
//    //        }
//    //    }
//}
//
//- (void)drawInContext:(CGContextRef)ctx
//{
//    //    UIGraphicsPushContext( ctx);
//    //    CGContextSetShouldAntialias(ctx, YES);
//    //    CGContextSetAllowsAntialiasing(ctx, true);
//    TSHPath * path = self.paths.firstObject;
//    self.strokeColor = path.pathColor.CGColor;
//    
//    [path.pathColor set];
//    if (path.isEraser)
//    {
//        //        CGContextSetBlendMode(CGContextRef  _Nullable c, <#CGBlendMode mode#>)
//        [path.bezierPath strokeWithBlendMode:kCGBlendModeClear alpha:1];
//        self.strokeColor = [UIColor clearColor].CGColor;
//        [[UIColor clearColor] set];
//        
//    }
//    
//    [path.bezierPath stroke];
//    //    [self createBasicAnimation];
//    //    UIGraphicsPopContext();
//}
//
//@end

//
//  ViewController.m
//  OpenGL01
//
//  Created by cfq on 25/12/2019.
//  Copyright © 2019 Mac. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "RenderView.h"

@interface ViewController ()

@property (nonatomic, strong) RenderView *glView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    _glView = [[RenderView alloc] initWithFrame:self.view.frame];
//    [self.view addSubview:_glView];
    
//    while (1) {
//        [_glView render];
//    }
    
    self.glView = (RenderView *)self.view;

}





@end

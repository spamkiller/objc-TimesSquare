//
//  TSQCalendarState.m
//  TimesSquare
//
//  Created by Jim Puls on 11/14/12.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "TSQCalendarView.h"
#import "TSQCalendarMonthHeaderCell.h"
#import "TSQCalendarRowCell.h"

@interface TSQCalendarView () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TSQCalendarMonthHeaderCell *headerView; // nil unless pinsHeaderToTop == YES

@end


@implementation TSQCalendarView

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return nil;
    }

    [self _TSQCalendarView_commonInit];

    return self;
}

- (id)initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self _TSQCalendarView_commonInit];
    
    return self;
}

- (void)_TSQCalendarView_commonInit;
{
    _selectionMode = TSQSelectionModeSingle;
    _selectedDates = @[];
    
    _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [self addSubview:_tableView];    
}

- (void)dealloc;
{
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
}

- (NSCalendar *)calendar;
{
    if (!_calendar) {
        self.calendar = [NSCalendar currentCalendar];
    }
    return _calendar;
}

- (Class)headerCellClass;
{
    if (!_headerCellClass) {
        self.headerCellClass = [TSQCalendarMonthHeaderCell class];
    }
    return _headerCellClass;
}

- (Class)rowCellClass;
{
    if (!_rowCellClass) {
        self.rowCellClass = [TSQCalendarRowCell class];
    }
    return _rowCellClass;
}

- (Class)cellClassForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (indexPath.row == 0 && !self.pinsHeaderToTop) {
        return [self headerCellClass];
    } else {
        return [self rowCellClass];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor;
{
    [super setBackgroundColor:backgroundColor];
    [self.tableView setBackgroundColor:backgroundColor];
}

- (void)setPinsHeaderToTop:(BOOL)pinsHeaderToTop;
{
    _pinsHeaderToTop = pinsHeaderToTop;
    [self setNeedsLayout];
}

- (void)setFirstDate:(NSDate *)firstDate;
{
    // clamp to the beginning of its month
    _firstDate = [self clampDate:firstDate toComponents:NSMonthCalendarUnit|NSYearCalendarUnit];
}

- (void)setLastDate:(NSDate *)lastDate;
{
    // clamp to the end of its month
    NSDate *firstOfMonth = [self clampDate:lastDate toComponents:NSMonthCalendarUnit|NSYearCalendarUnit];
    
    NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
    offsetComponents.month = 1;
    offsetComponents.day = -1;
    _lastDate = [self.calendar dateByAddingComponents:offsetComponents toDate:firstOfMonth options:0];
}

- (void)setFirstSelectableDate:(NSDate *)firstSelectableDate
{
    _firstSelectableDate = [self clampDate:firstSelectableDate toComponents:NSMonthCalendarUnit|NSYearCalendarUnit|NSDayCalendarUnit];
}

- (void)setSelectedDate:(NSDate *)newSelectedDate;
{
    NSAssert(self.selectionMode == TSQSelectionModeSingle, @"`selectionMode` must be set to `TSQSelectionModeSingle` to select a single date");
    
    // clamp to beginning of its day
    NSDate *startOfDay = [self clampDate:newSelectedDate];
    
    if ([self.delegate respondsToSelector:@selector(calendarView:shouldSelectDate:)] && ![self.delegate calendarView:self shouldSelectDate:startOfDay]) {
        return;
    }
    
    [[self cellForRowAtDate:_selectedDate] selectColumnForDate:nil];
    [[self cellForRowAtDate:startOfDay] selectColumnForDate:startOfDay];
    
    NSIndexPath *newIndexPath = [self indexPathForRowAtDate:startOfDay];
    CGRect newIndexPathRect = [self.tableView rectForRowAtIndexPath:newIndexPath];
    CGRect scrollBounds = self.tableView.bounds;
    
    if (self.pagingEnabled) {
        CGRect sectionRect = [self.tableView rectForSection:newIndexPath.section];
        [self.tableView setContentOffset:sectionRect.origin animated:YES];
    } else {
        if (CGRectGetMinY(scrollBounds) > CGRectGetMinY(newIndexPathRect)) {
            [self.tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
        } else if (CGRectGetMaxY(scrollBounds) < CGRectGetMaxY(newIndexPathRect)) {
            [self.tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }
    
    _selectedDate = startOfDay;
    
    if ([self.delegate respondsToSelector:@selector(calendarView:didSelectDate:)]) {
        [self.delegate calendarView:self didSelectDate:startOfDay];
    }
}

- (void)setSelectedDates:(NSArray *)selectedDates
{
    NSAssert(self.selectionMode == TSQSelectionModeMultiple, @"`selectionMode` must be set to `TSQSelectionModeMultiple` to select multiple dates");
    
    // clamp all dates
    NSMutableArray *clampedDates = [@[] mutableCopy];
    [selectedDates enumerateObjectsUsingBlock:^(NSDate *obj, NSUInteger idx, BOOL *stop) {
        [clampedDates addObject:[self clampDate:obj]];
    }];
    
    for (NSDate *date in _selectedDates) {
        [[self cellForRowAtDate:date] selectColumnForDate:date];
    }
    
    for (NSDate *date in clampedDates) {
        [[self cellForRowAtDate:date] selectColumnForDate:date];
    }
    
    _selectedDates = clampedDates;
    
    if ([self.delegate respondsToSelector:@selector(calendarView:didSelectDates:)]) {
        [self.delegate calendarView:self didSelectDates:clampedDates];
    }
}

- (void)scrollToDate:(NSDate *)date animated:(BOOL)animated
{
  NSInteger section = [self sectionForDate:date];
  [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:animated];
}

- (void)setScrollingEnabled:(BOOL)scrollingEnabled
{
    self.tableView.scrollEnabled = scrollingEnabled;
}

- (void)setBounces:(BOOL)bounces
{
    self.tableView.bounces = bounces;
}

- (TSQCalendarMonthHeaderCell *)makeHeaderCellWithIdentifier:(NSString *)identifier;
{
    TSQCalendarMonthHeaderCell *cell = [[[self headerCellClass] alloc] initWithCalendar:self.calendar reuseIdentifier:identifier];
    cell.backgroundColor = self.backgroundColor;
    cell.calendarView = self;
    return cell;
}

#pragma mark Calendar calculations

- (NSDate *)firstOfMonthForSection:(NSInteger)section;
{
    NSDateComponents *offset = [NSDateComponents new];
    offset.month = section;
    return [self.calendar dateByAddingComponents:offset toDate:self.firstDate options:0];
}

- (TSQCalendarRowCell *)cellForRowAtDate:(NSDate *)date;
{
    return (TSQCalendarRowCell *)[self.tableView cellForRowAtIndexPath:[self indexPathForRowAtDate:date]];
}

- (NSInteger)sectionForDate:(NSDate *)date;
{
  return [self.calendar components:NSMonthCalendarUnit fromDate:self.firstDate toDate:date options:0].month;
}

- (NSIndexPath *)indexPathForRowAtDate:(NSDate *)date;
{
    if (!date) {
        return nil;
    }
    
    NSInteger section = [self sectionForDate:date];
    NSDate *firstOfMonth = [self firstOfMonthForSection:section];
    
    NSInteger firstWeek = [self.calendar components:NSWeekOfMonthCalendarUnit fromDate:firstOfMonth].weekOfMonth;
    NSInteger targetWeek = [self.calendar components:NSWeekOfMonthCalendarUnit fromDate:date].weekOfMonth;
    
    return [NSIndexPath indexPathForRow:(self.pinsHeaderToTop ? 0 : 1) + targetWeek - firstWeek inSection:section];
}


- (NSDate *)clampDate:(NSDate *)date
{
    NSDate *startOfDay = [self clampDate:date toComponents:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit];
    return startOfDay;
}


- (NSDate *)clampDate:(NSDate *)date toComponents:(NSUInteger)unitFlags
{
    NSDateComponents *components = [self.calendar components:unitFlags fromDate:date];
    return [self.calendar dateFromComponents:components];
}


#pragma mark UIView

- (void)layoutSubviews;
{
    if (self.pinsHeaderToTop) {
        if (!self.headerView) {
            self.headerView = [self makeHeaderCellWithIdentifier:nil];
            if (self.tableView.visibleCells.count > 0) {
                self.headerView.firstOfMonth = [self.tableView.visibleCells[0] firstOfMonth];
            } else {
                self.headerView.firstOfMonth = self.firstDate;
            }
            [self addSubview:self.headerView];
        }
        CGRect bounds = self.bounds;
        CGRect headerRect;
        CGRect tableRect;
        CGRectDivide(bounds, &headerRect, &tableRect, [[self headerCellClass] cellHeight], CGRectMinYEdge);
        self.headerView.frame = headerRect;
        self.tableView.frame = tableRect;
    } else {
        if (self.headerView) {
            [self.headerView removeFromSuperview];
            self.headerView = nil;
        }
        self.tableView.frame = self.bounds;
    }
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    return 1 + [self.calendar components:NSMonthCalendarUnit fromDate:self.firstDate toDate:self.lastDate options:0].month;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    NSDate *firstOfMonth = [self firstOfMonthForSection:section];
    NSRange rangeOfWeeks = [self.calendar rangeOfUnit:NSWeekCalendarUnit inUnit:NSMonthCalendarUnit forDate:firstOfMonth];
    return (self.pinsHeaderToTop ? 0 : 1) + rangeOfWeeks.length;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (indexPath.row == 0 && !self.pinsHeaderToTop) {
        // month header
        static NSString *identifier = @"header";
        TSQCalendarMonthHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [self makeHeaderCellWithIdentifier:identifier];
        }
        return cell;
    } else {
        static NSString *identifier = @"row";
        TSQCalendarRowCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (!cell) {
            cell = [[[self rowCellClass] alloc] initWithCalendar:self.calendar reuseIdentifier:identifier];
            cell.backgroundColor = self.backgroundColor;
            cell.calendarView = self;
        }
        return cell;
    }
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    NSDate *firstOfMonth = [self firstOfMonthForSection:indexPath.section];
    [(TSQCalendarCell *)cell setFirstOfMonth:firstOfMonth];
    if (indexPath.row > 0 || self.pinsHeaderToTop) {
        NSInteger ordinalityOfFirstDay = [self.calendar ordinalityOfUnit:NSDayCalendarUnit inUnit:NSWeekCalendarUnit forDate:firstOfMonth];
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.day = 1 - ordinalityOfFirstDay;
        dateComponents.week = indexPath.row - (self.pinsHeaderToTop ? 0 : 1);
        [(TSQCalendarRowCell *)cell setBeginningDate:[self.calendar dateByAddingComponents:dateComponents toDate:firstOfMonth options:0]];
        
        if (self.selectionMode == TSQSelectionModeMultiple) {
            for (NSDate *date in self.selectedDates) {
                [(TSQCalendarRowCell *)cell selectColumnForDate:date];
            }
        } else {
            [(TSQCalendarRowCell *)cell selectColumnForDate:self.selectedDate];
        }
        
        BOOL isBottomRow = (indexPath.row == [self tableView:tableView numberOfRowsInSection:indexPath.section] - (self.pinsHeaderToTop ? 0 : 1));
        [(TSQCalendarRowCell *)cell setBottomRow:isBottomRow];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    return [[self cellClassForRowAtIndexPath:indexPath] cellHeight];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;
{
    if (self.pagingEnabled) {
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:*targetContentOffset];
        // If the target offset is at the third row or later, target the next month; otherwise, target the beginning of this month.
        NSInteger section = indexPath.section;
        if (indexPath.row > 2) {
            section++;
        }
        CGRect sectionRect = [self.tableView rectForSection:section];
        *targetContentOffset = sectionRect.origin;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
{
    if (self.pinsHeaderToTop && self.tableView.visibleCells.count > 0) {
        TSQCalendarCell *cell = self.tableView.visibleCells[0];
        self.headerView.firstOfMonth = cell.firstOfMonth;
    }
}

@end

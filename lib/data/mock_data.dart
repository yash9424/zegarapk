// Static mock data used across the admin and employee panels.

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.phone,
    required this.type,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String department;
  final String designation;
  final String phone;
  final String type;
  final String avatarUrl;
}

class DirectoryEmployee {
  const DirectoryEmployee({
    required this.name,
    required this.role,
    required this.team,
    required this.category,
    required this.avatarUrl,
    required this.online,
  });

  final String name;
  final String role;
  final String team;
  final String category;
  final String avatarUrl;
  final bool online;
}

class DirectoryFilter {
  const DirectoryFilter(this.label, this.count, this.category);
  final String label;
  final int count;
  final String? category; // null = "All"
}

class PayrollRecord {
  const PayrollRecord(this.month, this.year, this.amount, this.paid);
  final String month;
  final String year;
  final String amount;
  final bool paid; // true = Paid, false = Processing
}

class EmpLeaveRecord {
  const EmpLeaveRecord(this.dates, this.days, this.type, this.approved);
  final String dates;
  final String days;
  final String type;
  final bool approved;
}

enum DayStatus { present, late, absent }

class MyAttendanceDay {
  const MyAttendanceDay(
      this.date, this.weekday, this.status, this.inTime, this.outTime);
  final String date;
  final String weekday;
  final DayStatus status;
  final String inTime;
  final String outTime;
}

class Announcement {
  const Announcement(this.title, this.body, this.date, this.icon);
  final String title;
  final String body;
  final String date;
  final String icon; // semantic key, mapped to an icon in the UI
}

class DayAttendance {
  const DayAttendance({
    required this.name,
    required this.empId,
    required this.department,
    required this.status,
    required this.inTime,
    required this.outTime,
    required this.totalMins,
  });

  final String name;
  final String empId;
  final String department;
  final DayStatus status;
  final String inTime;
  final String outTime;
  final int totalMins;
}

enum LeaveStatus { pending, approved, rejected }

class LeaveRequest {
  const LeaveRequest({
    required this.name,
    required this.role,
    required this.department,
    required this.employeeId,
    required this.leaveType,
    required this.ref,
    required this.status,
    required this.dateRange,
    required this.duration,
    required this.reason,
    required this.footerNote,
    this.rejectionNote,
  });

  final String name;
  final String role;
  final String department;
  final String employeeId;
  final String leaveType;
  final String ref;
  final LeaveStatus status;
  final String dateRange;
  final String duration;
  final String reason;
  final String footerNote;
  final String? rejectionNote;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.name,
    required this.avatarUrl,
    required this.location,
    required this.time,
    required this.clockedIn,
  });

  final String name;
  final String avatarUrl;
  final String location;
  final String time;
  final bool clockedIn; // true = Clocked In, false = Clocked Out

  String get statusLabel => clockedIn ? 'Clocked In' : 'Clocked Out';
}

class MockData {
  MockData._();

  static const String adminName = 'Alexander Mitchell';
  static const String adminAvatar = 'https://i.pravatar.cc/150?img=12';
  static const String adminAvatarLarge = 'https://i.pravatar.cc/400?img=12';
  static const String adminEmployeeId = 'SP-94285-AM';
  static const String adminRole = 'Senior Systems Architect';
  static const String adminDepartment = 'Infrastructure Security';
  static const String adminEmail = 'a.mitchell@securepulse.com';
  static const String adminBiometric = 'Verified';

  // Logged-in employee (user@gmail.com) self profile + home data.
  static const String employeeName = 'Alexander Mercer';
  static const String employeeRole = 'Senior Security Systems Engineer';
  static const String employeeDepartment = 'Engineering & Ops';
  static const String employeeId = 'SP-7729-2024';
  static const String employeeLocation = 'HQ - Sector 4';
  static const String employeeEmail = 'user@gmail.com';
  static const String employeeAvatar = 'https://i.pravatar.cc/400?img=13';

  // Profile → Payroll History.
  static const String empBaseSalary = '₹8,450.00';
  static const List<PayrollRecord> payroll = [
    PayrollRecord('March', '2024', '₹8,450.00', true),
    PayrollRecord('February', '2024', '₹8,450.00', true),
    PayrollRecord('January', '2024', '₹8,450.00', false),
    PayrollRecord('December', '2023', '₹8,450.00', true),
  ];

  // Profile → Leave Requests.
  static const int annualUsed = 14;
  static const int annualTotal = 24;
  static const int sickUsed = 2;
  static const int sickTotal = 10;
  static const List<EmpLeaveRecord> empLeaveHistory = [
    EmpLeaveRecord('Apr 12 -\nApr 15', '4 Days', 'Annual Leave', true),
    EmpLeaveRecord('Feb 02 -\nFeb 02', '1 Day', 'Sick Leave', true),
    EmpLeaveRecord('Jan 08 -\nJan 09', '2 Days', 'Annual Leave', true),
  ];

  // Employee → My Attendance history.
  static const List<MyAttendanceDay> myAttendance = [
    MyAttendanceDay('May 31', 'Saturday', DayStatus.present, '09:02 AM', '06:05 PM'),
    MyAttendanceDay('May 30', 'Friday', DayStatus.present, '08:58 AM', '06:01 PM'),
    MyAttendanceDay('May 29', 'Thursday', DayStatus.late, '09:41 AM', '06:30 PM'),
    MyAttendanceDay('May 28', 'Wednesday', DayStatus.present, '08:55 AM', '05:58 PM'),
    MyAttendanceDay('May 27', 'Tuesday', DayStatus.present, '09:00 AM', '06:02 PM'),
    MyAttendanceDay('May 26', 'Monday', DayStatus.absent, '--:--', '--:--'),
    MyAttendanceDay('May 24', 'Saturday', DayStatus.present, '09:05 AM', '06:10 PM'),
    MyAttendanceDay('May 23', 'Friday', DayStatus.late, '09:50 AM', '06:45 PM'),
  ];

  // Employee → Announcements (empty for now; add items here in future).
  static const List<Announcement> announcements = [];

  // Profile → Profession (employment details).
  static const String empJoiningDate = 'May 15, 2021';
  static const String empReportingTo = 'Marcus Thorne';
  static const String empEmploymentType = 'Permanent Full-time';

  static const String empPresentDays = '21 / 23';
  static const String empOnTime = '94%';
  static const String empLeaveBalance = '8';

  static const List<AttendanceRecord> employeeRecent = [
    AttendanceRecord(
      name: 'Today',
      avatarUrl: '',
      location: 'Main Gate',
      time: '09:02 AM',
      clockedIn: true,
    ),
    AttendanceRecord(
      name: 'Yesterday',
      avatarUrl: '',
      location: 'Main Gate',
      time: '06:04 PM',
      clockedIn: false,
    ),
    AttendanceRecord(
      name: 'Wed, May 29',
      avatarUrl: '',
      location: 'Main Gate',
      time: '08:58 AM',
      clockedIn: true,
    ),
  ];

  static const List<String> departments = [
    'Engineering',
    'Human Resources',
    'Sales',
    'Marketing',
    'Finance',
    'Operations',
    'Security',
  ];

  static const List<String> employmentTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Intern',
  ];

  static const List<Employee> employees = [
    Employee(
      id: 'EMP001',
      name: 'Alexander Mitchell',
      department: 'Engineering',
      designation: 'Senior Developer',
      phone: '+1 415 555 0101',
      type: 'Full-time',
      avatarUrl: 'https://i.pravatar.cc/400?img=12',
    ),
    Employee(
      id: 'EMP002',
      name: 'Sara Lynch',
      department: 'Human Resources',
      designation: 'HR Manager',
      phone: '+1 415 555 0102',
      type: 'Full-time',
      avatarUrl: 'https://i.pravatar.cc/400?img=47',
    ),
    Employee(
      id: 'EMP003',
      name: 'James Chen',
      department: 'Sales',
      designation: 'Account Executive',
      phone: '+1 415 555 0103',
      type: 'Full-time',
      avatarUrl: 'https://i.pravatar.cc/400?img=33',
    ),
    Employee(
      id: 'EMP004',
      name: 'Priya Sharma',
      department: 'Marketing',
      designation: 'Content Lead',
      phone: '+1 415 555 0104',
      type: 'Contract',
      avatarUrl: 'https://i.pravatar.cc/400?img=45',
    ),
  ];

  // Chips shown above the directory list (label + count + category key).
  static const List<DirectoryFilter> directoryFilters = [
    DirectoryFilter('All', 142, null),
    DirectoryFilter('Engineering', 45, 'Engineering'),
    DirectoryFilter('Security', 12, 'Security'),
    DirectoryFilter('Operations', 30, 'Operations'),
    DirectoryFilter('R&D', 25, 'R&D'),
  ];

  static const List<DirectoryEmployee> directory = [
    DirectoryEmployee(
      name: 'Marcus Thorne',
      role: 'Director of Security Systems',
      team: 'Corporate Ops',
      category: 'Security',
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
      online: true,
    ),
    DirectoryEmployee(
      name: 'Elena Rodriguez',
      role: 'Lead Hardware Architect',
      team: 'R&D Engineering',
      category: 'Engineering',
      avatarUrl: 'https://i.pravatar.cc/150?img=44',
      online: true,
    ),
    DirectoryEmployee(
      name: 'Jameson Wu',
      role: 'Network Security Analyst',
      team: 'Cyber Intel',
      category: 'Security',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      online: false,
    ),
    DirectoryEmployee(
      name: 'Sarah Jenkins',
      role: 'Fleet Logistics Manager',
      team: 'Distribution',
      category: 'Operations',
      avatarUrl: 'https://i.pravatar.cc/150?img=31',
      online: true,
    ),
    DirectoryEmployee(
      name: 'Arthur Vance',
      role: 'Infrastructure Lead',
      team: 'On-site Ops',
      category: 'Operations',
      avatarUrl: 'https://i.pravatar.cc/150?img=59',
      online: false,
    ),
    DirectoryEmployee(
      name: 'Priya Sharma',
      role: 'Firmware Engineer',
      team: 'R&D Engineering',
      category: 'R&D',
      avatarUrl: 'https://i.pravatar.cc/150?img=45',
      online: true,
    ),
    DirectoryEmployee(
      name: 'David Okoro',
      role: 'SOC Analyst',
      team: 'Cyber Intel',
      category: 'Security',
      avatarUrl: 'https://i.pravatar.cc/150?img=15',
      online: true,
    ),
    DirectoryEmployee(
      name: 'Mia Rossi',
      role: 'Supply Coordinator',
      team: 'Distribution',
      category: 'Operations',
      avatarUrl: 'https://i.pravatar.cc/150?img=20',
      online: false,
    ),
    DirectoryEmployee(
      name: 'Liam Foster',
      role: 'Backend Engineer',
      team: 'Platform',
      category: 'Engineering',
      avatarUrl: 'https://i.pravatar.cc/150?img=68',
      online: true,
    ),
  ];

  // Admin attendance tab.
  static const String attendanceMonth = 'October 2023';
  static const String attendancePresent = '42 / 48';
  static const String attendanceOnTime = '88%';

  static const List<DayAttendance> dayAttendance = [
    DayAttendance(
      name: 'John Doe',
      empId: 'EMP001',
      department: 'Engineering',
      status: DayStatus.present,
      inTime: '09:00 AM',
      outTime: '06:00 PM',
      totalMins: 540,
    ),
    DayAttendance(
      name: 'Sarah Jenkins',
      empId: 'EMP024',
      department: 'UI/UX Design',
      status: DayStatus.present,
      inTime: '08:52 AM',
      outTime: '05:30 PM',
      totalMins: 518,
    ),
    DayAttendance(
      name: 'Michael Chen',
      empId: 'EMP108',
      department: 'Operations',
      status: DayStatus.late,
      inTime: '09:45 AM',
      outTime: '06:45 PM',
      totalMins: 540,
    ),
    DayAttendance(
      name: 'Priya Sharma',
      empId: 'EMP045',
      department: 'R&D Engineering',
      status: DayStatus.present,
      inTime: '08:58 AM',
      outTime: '06:05 PM',
      totalMins: 547,
    ),
    DayAttendance(
      name: 'David Okoro',
      empId: 'EMP077',
      department: 'Security',
      status: DayStatus.late,
      inTime: '10:05 AM',
      outTime: '07:00 PM',
      totalMins: 535,
    ),
  ];

  static const List<LeaveRequest> leaveRequests = [
    LeaveRequest(
      name: 'Alexander Mitchell',
      role: 'Senior Systems Architect',
      department: 'Infrastructure Security',
      employeeId: 'SP-94285-AM',
      leaveType: 'Annual Leave',
      ref: '#LR-9042',
      status: LeaveStatus.approved,
      dateRange: 'Mar 15 - Mar 18, 2024',
      duration: '4 Days',
      reason:
          'Visiting family in the countryside for a long-planned reunion.',
      footerNote: 'Approved by Sarah J. • 2d ago',
    ),
    LeaveRequest(
      name: 'Elena Rodriguez',
      role: 'UX/UI Design Lead',
      department: 'Product Design',
      employeeId: 'ER-22894-PD',
      leaveType: 'Sick Leave',
      ref: '#LR-9105',
      status: LeaveStatus.pending,
      dateRange: 'Apr 02, 2024',
      duration: '1 Day',
      reason:
          "Routine medical check-up following last month's consultation.",
      footerNote: 'Submitted 4h ago',
    ),
    LeaveRequest(
      name: 'Marcus Thorne',
      role: 'Project Coordinator',
      department: 'Operations',
      employeeId: 'MT-45102-OP',
      leaveType: 'Personal Leave',
      ref: '#LR-8871',
      status: LeaveStatus.rejected,
      dateRange: 'Feb 20 - Feb 21, 2024',
      duration: '2 Days',
      reason: 'Attending to an urgent personal matter at home.',
      footerNote: 'Reviewed by Mark T. • 1w ago',
      rejectionNote:
          'High project volume during this period. Please reschedule for late March.',
    ),
    LeaveRequest(
      name: 'Priya Sharma',
      role: 'Firmware Engineer',
      department: 'R&D Engineering',
      employeeId: 'PS-33781-RD',
      leaveType: 'Casual Leave',
      ref: '#LR-9210',
      status: LeaveStatus.pending,
      dateRange: 'Apr 10, 2024',
      duration: '1 Day',
      reason: 'Personal errands that cannot be scheduled after hours.',
      footerNote: 'Submitted 1d ago',
    ),
    LeaveRequest(
      name: 'Sarah Jenkins',
      role: 'Fleet Logistics Manager',
      department: 'Distribution',
      employeeId: 'SJ-77410-DS',
      leaveType: 'Annual Leave',
      ref: '#LR-9001',
      status: LeaveStatus.approved,
      dateRange: 'May 02 - May 06, 2024',
      duration: '5 Days',
      reason: 'Pre-booked vacation with family.',
      footerNote: 'Approved by Mark T. • 3d ago',
    ),
  ];

  static const List<AttendanceRecord> dailyAttendance = [
    AttendanceRecord(
      name: 'Sara Lynch',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
      location: 'Main Gate',
      time: '09:05 AM',
      clockedIn: true,
    ),
    AttendanceRecord(
      name: 'James Chen',
      avatarUrl: 'https://i.pravatar.cc/150?img=33',
      location: 'Lobby',
      time: '08:58 AM',
      clockedIn: false,
    ),
    AttendanceRecord(
      name: 'Priya Sharma',
      avatarUrl: 'https://i.pravatar.cc/150?img=45',
      location: 'Main Gate',
      time: '08:52 AM',
      clockedIn: true,
    ),
    AttendanceRecord(
      name: 'David Okoro',
      avatarUrl: 'https://i.pravatar.cc/150?img=15',
      location: 'Workshop',
      time: '08:47 AM',
      clockedIn: true,
    ),
    AttendanceRecord(
      name: 'Mia Rossi',
      avatarUrl: 'https://i.pravatar.cc/150?img=20',
      location: 'Lobby',
      time: '08:40 AM',
      clockedIn: false,
    ),
  ];
}

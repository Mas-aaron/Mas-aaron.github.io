import 'package:flutter/material.dart';

class DineInScheduler extends StatefulWidget {
  final DateTime? selectedTime;
  final Function(DateTime?) onTimeChanged;
  final int estimatedPrepTime;

  const DineInScheduler({
    Key? key,
    this.selectedTime,
    required this.onTimeChanged,
    this.estimatedPrepTime = 30,
  }) : super(key: key);

  @override
  State<DineInScheduler> createState() => _DineInSchedulerState();
}

class _DineInSchedulerState extends State<DineInScheduler> {
  bool _isASAP = true;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _scheduledTime = widget.selectedTime;
    _isASAP = widget.selectedTime == null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'When would you like to dine?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ASAP Option
          GestureDetector(
            onTap: () {
              setState(() {
                _isASAP = true;
                _scheduledTime = null;
              });
              widget.onTimeChanged(null);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isASAP ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isASAP ? Colors.blue : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    color: _isASAP ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASAP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isASAP ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Ready in ${widget.estimatedPrepTime} minutes',
                          style: TextStyle(
                            fontSize: 14,
                            color: _isASAP ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Schedule Option
          GestureDetector(
            onTap: () {
              setState(() {
                _isASAP = false;
              });
              _selectDateTime();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_isASAP ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: !_isASAP ? Colors.blue : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: !_isASAP ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: !_isASAP ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _scheduledTime != null
                              ? _formatDateTime(_scheduledTime!)
                              : 'Choose your arrival time',
                          style: TextStyle(
                            fontSize: 14,
                            color: !_isASAP ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isASAP)
                    Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
          
          if (!_isASAP && _scheduledTime != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your food will be ready when you arrive',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final minTime = now.add(Duration(minutes: widget.estimatedPrepTime + 15));
    
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime ?? minTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? minTime),
      );
      
      if (time != null) {
        final selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        
        if (selectedDateTime.isBefore(minTime)) {
          _showTimeWarning();
          return;
        }
        
        setState(() {
          _scheduledTime = selectedDateTime;
        });
        widget.onTimeChanged(selectedDateTime);
      }
    }
  }

  void _showTimeWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please select a time at least ${widget.estimatedPrepTime + 15} minutes from now',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (selectedDate == today) {
      dateStr = 'Today';
    } else if (selectedDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}';
    }
    
    final timeStr = TimeOfDay.fromDateTime(dateTime).format(context);
    return '$dateStr at $timeStr';
  }
}

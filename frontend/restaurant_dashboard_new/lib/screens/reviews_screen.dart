import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_dashboard_new/models/restaurant_review.dart';
import 'package:restaurant_dashboard_new/services/restaurant_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ReviewsScreen extends StatefulWidget {
  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  List<RestaurantReview>? _reviews;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final reviews = await _restaurantService.fetchRestaurantReviews();
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _averageRating {
    if (_reviews == null || _reviews!.isEmpty) return 0.0;
    return _reviews!.map((r) => r.rating).reduce((a, b) => a + b) / _reviews!.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback & Reviews'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[100],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      return Center(child: Text('Error: $_error'));
    } else if (_reviews == null || _reviews!.isEmpty) {
      return Center(child: Text('No reviews found.'));
    } else {
      return RefreshIndicator(
        onRefresh: _fetchReviews,
        child: ListView(
          children: [
            _buildHeader(),
            ..._reviews!.map((review) => _buildReviewCard(review)).toList(),
          ],
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            _averageRating.toStringAsFixed(1),
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Based on ${_reviews!.length} ratings',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              RatingBar.builder(
                initialRating: _averageRating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 24.0,
                itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                ignoreGestures: true,
                onRatingUpdate: (rating) {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(RestaurantReview review) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.customerName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  DateFormat.yMMMd().format(review.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 4),
            RatingBar.builder(
              initialRating: review.rating,
              itemCount: 5,
              itemSize: 18.0,
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              ignoreGestures: true,
              onRatingUpdate: (rating) {},
            ),
            SizedBox(height: 12),
            Text(review.comment, style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Text(
              '${review.orderItemsCount} item(s) for \$${review.orderTotal.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Divider(height: 24),
            _buildReplySection(review),
          ],
        ),
      ),
    );
  }

  Widget _buildReplySection(RestaurantReview review) {
    if (review.replyText != null && review.replyText!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your reply',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
          ),
          SizedBox(height: 4),
          Text(review.replyText!),
          SizedBox(height: 4),
          Text(
            'Replied on ${DateFormat.yMMMd().format(review.repliedAt!)}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        child: Text('Reply'),
        onPressed: () => _showReplyDialog(review),
      ),
    );
  }

  void _showReplyDialog(RestaurantReview review) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reply to ${review.customerName}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Write your reply...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Submit Reply'),
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    final updatedReview = await _restaurantService.replyToReview(review.id, controller.text);
                    setState(() {
                      final index = _reviews!.indexWhere((r) => r.id == review.id);
                      if (index != -1) {
                        _reviews![index] = updatedReview;
                      }
                    });
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to post reply: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}

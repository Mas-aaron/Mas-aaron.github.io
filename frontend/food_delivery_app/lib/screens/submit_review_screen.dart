import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:food_delivery_app/services/api_service.dart';

class SubmitReviewScreen extends StatefulWidget {
  final int orderId;
  final int? riderId;

  const SubmitReviewScreen({Key? key, required this.orderId, this.riderId}) : super(key: key);

  @override
  _SubmitReviewScreenState createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  double _rating = 0;
  double _riderRating = 0;
  final _commentController = TextEditingController();
  final _riderCommentController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;

    void _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating for the order.')),
      );
      return;
    }
    if (widget.riderId != null && _riderRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating for the rider.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Submit order review
      await _apiService.submitOrderReview(
        orderId: widget.orderId,
        rating: _rating,
        comment: _commentController.text,
      );

      // Submit rider review if applicable
      if (widget.riderId != null) {
        await _apiService.submitRiderReview(
          orderId: widget.orderId,
          riderId: widget.riderId!,
          rating: _riderRating,
          comment: _riderCommentController.text,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _riderCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate this Order', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFfe5722),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Order Rating
            Text(
              'Rate Your Order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            SizedBox(height: 12),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),

            // Rider Rating (only if a rider is assigned)
            if (widget.riderId != null)
              Padding(
                padding: const EdgeInsets.only(top: 30.0),
                child: Column(
                  children: [
                    Text(
                      'Rate Your Rider',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 12),
                    RatingBar.builder(
                      initialRating: _riderRating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: false,
                      itemCount: 5,
                      itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _riderRating = rating;
                        });
                      },
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: 'Write Your Order Review',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),

            // Rider Comment
            if (widget.riderId != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: TextField(
                  controller: _riderCommentController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'Write a Review for Your Rider',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
              ),
            SizedBox(height: 30),
            _isSubmitting
                ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFfe5722)))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReview,
                      child: Text('Submit Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFfe5722),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

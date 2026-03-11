import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

/// Shows doctor reviews and allows patients to submit ratings.
class DoctorReviewsScreen extends StatefulWidget {
  final TeleMedicineApiClient api;
  final String doctorId;
  final String doctorName;
  final String? consultationId;

  const DoctorReviewsScreen({
    super.key,
    required this.api,
    required this.doctorId,
    required this.doctorName,
    this.consultationId,
  });

  @override
  State<DoctorReviewsScreen> createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    final resp = await widget.api.getDoctorReviews(widget.doctorId);
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(resp.data!['reviews'] ?? []);
        _averageRating = (resp.data!['averageRating'] as num?)?.toDouble() ?? 0;
        _totalReviews = (resp.data!['totalReviews'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _showSubmitReviewDialog() {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    bool anonymous = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Rate Dr. ${widget.doctorName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(
                    i < selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                  onPressed: () => setDialogState(() => selectedRating = i + 1),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Submit anonymously'),
                value: anonymous,
                onChanged: (v) => setDialogState(() => anonymous = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final resp = await widget.api.submitDoctorReview(
                  doctorId: widget.doctorId,
                  rating: selectedRating,
                  comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                  consultationId: widget.consultationId,
                  isAnonymous: anonymous,
                );
                if (!mounted) return;
                if (resp.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review submitted!'), backgroundColor: Colors.green),
                  );
                  _loadReviews();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(resp.error?.toString() ?? 'Failed to submit review')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reviews for Dr. ${widget.doctorName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitReviewDialog,
        icon: const Icon(Icons.rate_review),
        label: const Text('Write Review'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Rating summary
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.teal.withAlpha(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (i) => Icon(
                              i < _averageRating.round() ? Icons.star : Icons.star_border,
                              color: Colors.amber, size: 20,
                            )),
                          ),
                          const SizedBox(height: 4),
                          Text('$_totalReviews review${_totalReviews == 1 ? '' : 's'}',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                // Reviews list
                Expanded(
                  child: _reviews.isEmpty
                      ? const Center(child: Text('No reviews yet — be the first!'))
                      : RefreshIndicator(
                          onRefresh: _loadReviews,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reviews.length,
                            itemBuilder: (ctx, i) => _buildReviewCard(_reviews[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final createdAt = review['createdAt'] != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(review['createdAt'].toString()))
        : '';
    final rating = (review['rating'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) => Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 16,
                )),
                const Spacer(),
                Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review['patientName']?.toString() ?? 'Anonymous',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review['comment'].toString()),
            ],
          ],
        ),
      ),
    );
  }
}

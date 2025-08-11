import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/network_interceptor.dart';

class NetworkDebugPanel extends StatefulWidget {
  final bool enabled;
  
  const NetworkDebugPanel({
    Key? key,
    this.enabled = false,
  }) : super(key: key);

  @override
  State<NetworkDebugPanel> createState() => _NetworkDebugPanelState();
}

class _NetworkDebugPanelState extends State<NetworkDebugPanel>
    with TickerProviderStateMixin {
  
  final NetworkInterceptor _interceptor = NetworkInterceptor();
  late TabController _tabController;
  
  String _filterMethod = 'All';
  String _searchQuery = '';
  bool _showOnlyErrors = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _interceptor.addListener(_onRequestUpdate);
  }
  
  void _onRequestUpdate(NetworkRequest request) {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildStatisticsTab(),
                _buildToolsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.network_check,
          color: Colors.cyan,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Network Debug Panel',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildStatusIndicator(),
        const SizedBox(width: 16),
        _buildClearButton(),
      ],
    );
  }
  
  Widget _buildStatusIndicator() {
    final stats = NetworkStatistics.fromInterceptor(_interceptor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stats.successRate > 0.8 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stats.successRate > 0.8 ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            stats.successRate > 0.8 ? Icons.check_circle : Icons.warning,
            color: stats.successRate > 0.8 ? Colors.green : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '${(stats.successRate * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: stats.successRate > 0.8 ? Colors.green : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildClearButton() {
    return GestureDetector(
      onTap: () {
        _interceptor.clearHistory();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: const Text(
          'Clear',
          style: TextStyle(
            color: Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Requests'),
        Tab(text: 'Statistics'),
        Tab(text: 'Tools'),
      ],
      labelColor: Colors.cyan,
      unselectedLabelColor: Colors.white54,
      indicatorColor: Colors.cyan,
      indicatorSize: TabBarIndicatorSize.tab,
    );
  }
  
  Widget _buildRequestsTab() {
    return Column(
      children: [
        _buildFilters(),
        const SizedBox(height: 8),
        Expanded(
          child: _buildRequestsList(),
        ),
      ],
    );
  }
  
  Widget _buildFilters() {
    return Row(
      children: [
        // Method filter
        DropdownButton<String>(
          value: _filterMethod,
          onChanged: (value) {
            setState(() {
              _filterMethod = value ?? 'All';
            });
          },
          items: ['All', 'GET', 'POST', 'PUT', 'DELETE', 'PATCH']
              .map((method) => DropdownMenuItem(
                    value: method,
                    child: Text(
                      method,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ))
              .toList(),
          dropdownColor: Colors.grey[800],
          underline: Container(),
          style: const TextStyle(color: Colors.white),
          iconEnabledColor: Colors.white,
        ),
        
        const SizedBox(width: 16),
        
        // Search field
        Expanded(
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search URL...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.cyan),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Error filter
        GestureDetector(
          onTap: () {
            setState(() {
              _showOnlyErrors = !_showOnlyErrors;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _showOnlyErrors ? Colors.red.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error,
                  color: _showOnlyErrors ? Colors.red : Colors.white54,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Errors',
                  style: TextStyle(
                    color: _showOnlyErrors ? Colors.red : Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRequestsList() {
    final filteredRequests = _getFilteredRequests();
    
    if (filteredRequests.isEmpty) {
      return const Center(
        child: Text(
          'No requests found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[filteredRequests.length - 1 - index]; // Reverse order
        return _buildRequestItem(request);
      },
    );
  }
  
  List<NetworkRequest> _getFilteredRequests() {
    var requests = _interceptor.requests;
    
    // Apply filters
    if (_filterMethod != 'All') {
      requests = requests.where((r) => r.method == _filterMethod).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      requests = requests.where((r) => r.url.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    if (_showOnlyErrors) {
      requests = requests.where((r) => r.hasError || (r.statusCode != null && r.statusCode! >= 400)).toList();
    }
    
    return requests;
  }
  
  Widget _buildRequestItem(NetworkRequest request) {
    Color statusColor;
    IconData statusIcon;
    
    if (request.hasError || (request.statusCode != null && request.statusCode! >= 400)) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (request.isSuccessful) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }
    
    return GestureDetector(
      onTap: () => _showRequestDetails(request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Status icon
            Icon(statusIcon, color: statusColor, size: 16),
            const SizedBox(width: 8),
            
            // Method
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _getMethodColor(request.method).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                request.method,
                style: TextStyle(
                  color: _getMethodColor(request.method),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(width: 8),
            
            // URL and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.shortUrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    request.statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            
            // Duration
            if (request.isCompleted)
              Text(
                '${request.duration}ms',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET': return Colors.blue;
      case 'POST': return Colors.green;
      case 'PUT': return Colors.orange;
      case 'DELETE': return Colors.red;
      case 'PATCH': return Colors.purple;
      default: return Colors.grey;
    }
  }
  
  void _showRequestDetails(NetworkRequest request) {
    showDialog(
      context: context,
      builder: (context) => _RequestDetailsDialog(request: request),
    );
  }
  
  Widget _buildStatisticsTab() {
    final stats = NetworkStatistics.fromInterceptor(_interceptor);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatCard('Total Requests', stats.totalRequests.toString(), Icons.call_made),
          _buildStatCard('Successful', stats.successfulRequests.toString(), Icons.check_circle),
          _buildStatCard('Failed', stats.failedRequests.toString(), Icons.error),
          _buildStatCard('Success Rate', '${(stats.successRate * 100).toStringAsFixed(1)}%', Icons.trending_up),
          _buildStatCard('Avg Response Time', '${stats.averageResponseTime.toStringAsFixed(1)}ms', Icons.timer),
          _buildStatCard('Data Transferred', '${(stats.totalDataTransferred / 1024).toStringAsFixed(1)} KB', Icons.swap_vert),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToolsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Tools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildToolButton(
            'Export Request History',
            'Export all requests as JSON',
            Icons.download,
            _exportRequestHistory,
          ),
          
          _buildToolButton(
            'Generate cURL Commands',
            'Copy cURL commands for all requests',
            Icons.code,
            _generateCurlCommands,
          ),
          
          _buildToolButton(
            'Clear All Data',
            'Remove all stored network data',
            Icons.clear_all,
            _clearAllData,
          ),
        ],
      ),
    );
  }
  
  Widget _buildToolButton(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }
  
  void _exportRequestHistory() {
    // Implementation for exporting request history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality would be implemented here')),
    );
  }
  
  void _generateCurlCommands() {
    final requests = _interceptor.requests;
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No requests to export')),
      );
      return;
    }
    
    final curlCommands = requests.map((req) => _interceptor.exportToCurl(req)).join('\n\n');
    Clipboard.setData(ClipboardData(text: curlCommands));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('cURL commands copied to clipboard')),
    );
  }
  
  void _clearAllData() {
    _interceptor.clearHistory();
    setState(() {});
  }
  
  @override
  void dispose() {
    _interceptor.removeListener(_onRequestUpdate);
    _tabController.dispose();
    super.dispose();
  }
}

class _RequestDetailsDialog extends StatelessWidget {
  final NetworkRequest request;
  
  const _RequestDetailsDialog({required this.request});
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Request Details',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Method', request.method),
              _buildDetailRow('URL', request.url),
              _buildDetailRow('Status', request.statusText),
              if (request.duration > 0)
                _buildDetailRow('Duration', '${request.duration}ms'),
              
              const SizedBox(height: 16),
              
              if (request.data != null) ...[
                const Text('Request Data:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.data.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              if (request.responseData != null) ...[
                const Text('Response Data:', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.responseData.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final curl = NetworkInterceptor().exportToCurl(request);
            Clipboard.setData(ClipboardData(text: curl));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('cURL command copied to clipboard')),
            );
          },
          child: const Text('Copy cURL', style: TextStyle(color: Colors.cyan)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
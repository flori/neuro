#include "ruby.h"
#include <assert.h>
#include <math.h>

#define CAST2FLOAT(obj) \
    if (TYPE(obj) != T_FLOAT && rb_respond_to(obj, id_to_f)) \
            obj = rb_funcall(obj, id_to_f, 0, 0); \
        else \
            Check_Type(obj, T_FLOAT)
#define SYM(x) ID2SYM(rb_intern(x))
#define feed \
    feed2layer(network->input_size, network->hidden_size, \
        network->hidden_layer, network->tmp_input); \
    for (i = 0; i < network->hidden_size; i++) \
        network->tmp_hidden[i] = network->hidden_layer[i]->output; \
    feed2layer(network->hidden_size, network->output_size, \
        network->output_layer, network->tmp_hidden)
#define DEFAULT_MAX_ITERATIONS  10000
#define DEFAULT_DEBUG_STEP      1000

static VALUE rb_mNeuro, rb_cNetwork, rb_cNeuroError;
static ID id_to_f, id_class, id_name;

/* Infrastructure */

typedef struct NodeStruct {
    long      number_weights;
    double   *weights;
    double   output;
} Node;

typedef struct NetworkStruct {
    int input_size;
    int hidden_size;
    int output_size;
    Node** hidden_layer;
    Node** output_layer;
    int learned;
    int debug_step;
    VALUE debug;
    int max_iterations;
    double *tmp_input;
    double *tmp_hidden;
    double *tmp_output;
} Network;

/* Node methods */

static Node *Node_create(long weights)
{
    Node *node;
    long i;
    assert(weights > 0);
    node = ALLOC(Node);
    MEMZERO(node, Node, 1);
    node->weights = ALLOC_N(double, weights);
    node->number_weights = weights;
    for (i = 0; i < weights; i++)
        node->weights[i] = 0.5 - rand() / (float) RAND_MAX;
    node->output  = 0.0;
    return node;
}

static Node *Node_from_hash(VALUE hash)
{
    long i, len;
    Node *node;
    VALUE weights = rb_hash_aref(hash, SYM("weights"));
    VALUE output = rb_hash_aref(hash, SYM("output"));
    Check_Type(output, T_FLOAT);
    Check_Type(weights, T_ARRAY);
    len = RARRAY_LEN(weights);
    node = Node_create(len);
    node->output = RFLOAT_VALUE(output);
    for (i = 0; i < len; i++)
        node->weights[i] = RFLOAT_VALUE(rb_ary_entry(weights, i));
    return node;
}

static void Node_destroy(Node *node)
{
    MEMZERO(node->weights, double, node->number_weights);
    xfree(node->weights);
    MEMZERO(node, Node, 1);
    xfree(node);
}

static VALUE Node_to_hash(Node *node)
{
    VALUE result = rb_hash_new(), weights = rb_ary_new2(node->number_weights);
    long i;
    rb_hash_aset(result, SYM("output"), rb_float_new(node->output));
    for (i = 0; i < node->number_weights; i++)
        rb_ary_store(weights, i, rb_float_new(node->weights[i]));
    rb_hash_aset(result, SYM("weights"), weights);
    return result;
}

/* Network methods */

static Network *Network_allocate()
{
    Network *network = ALLOC(Network);
    MEMZERO(network, Network, 1);
    return network;
}

static void Network_init(Network *network, int input_size, int hidden_size,
    int output_size, int learned)
{
    if (input_size <= 0) rb_raise(rb_cNeuroError, "input_size <= 0");
    if (hidden_size <= 0) rb_raise(rb_cNeuroError, "hidden_size <= 0");
    if (output_size <= 0) rb_raise(rb_cNeuroError, "output_size <= 0");
    if (learned < 0) rb_raise(rb_cNeuroError, "learned < 0");
    network->input_size  = input_size;
    network->hidden_size = hidden_size;
    network->output_size = output_size;
    network->learned     = learned;
    network->hidden_layer = ALLOC_N(Node*, hidden_size);
    network->output_layer = ALLOC_N(Node*, output_size);
    network->debug           = Qnil; /* Debugging switched off */
    network->debug_step      = DEFAULT_DEBUG_STEP;
    network->max_iterations  = DEFAULT_MAX_ITERATIONS;
    network->tmp_input  = ALLOC_N(double, input_size);
    MEMZERO(network->tmp_input, double, network->input_size);
    network->tmp_hidden = ALLOC_N(double, hidden_size);
    MEMZERO(network->tmp_hidden, double, network->hidden_size);
    network->tmp_output = ALLOC_N(double, output_size);
    MEMZERO(network->tmp_output, double, network->output_size);
}

static void Network_init_weights(Network *network)
{
    int i;
    for (i = 0; i < network->hidden_size; i++)
        network->hidden_layer[i] = Node_create(network->input_size);
    for (i = 0; i < network->output_size; i++)
        network->output_layer[i] = Node_create(network->hidden_size);
}

static void Network_debug_error(Network *network, long count, double error, double
        max_error)
{
    VALUE argv[5];
    int argc = 5;
    if (!NIL_P(network->debug)) {
        argv[0] = rb_str_new2("%6u.\tcount = %u\terror = %e\tmax_error = %e\n");
        argv[1] = INT2NUM(network->learned);
        argv[2] = INT2NUM(count);
        argv[3] = rb_float_new(error / 2.0);
        argv[4] = rb_float_new(max_error / 2.0);
        rb_io_write(network->debug, rb_f_sprintf(argc, argv));
    }
}

static void Network_debug_bail_out(Network *network)
{
    VALUE argv[2];
    int argc = 2;
    if (!NIL_P(network->debug)) {
        argv[0] = rb_str_new2("Network didn't converge after %u iterations! => Bailing out!\n");
        argv[1] = INT2NUM(network->max_iterations);
        rb_io_write(network->debug, rb_f_sprintf(argc, argv));
    }
}

static VALUE Network_to_hash(Network *network)
{
    int i;
    VALUE hidden_layer, output_layer, result = rb_hash_new();

    rb_hash_aset(result, SYM("input_size"), INT2NUM(network->input_size));
    rb_hash_aset(result, SYM("hidden_size"), INT2NUM(network->hidden_size));
    rb_hash_aset(result, SYM("output_size"), INT2NUM(network->output_size));
    hidden_layer = rb_ary_new2(network->hidden_size);
    for (i = 0; i < network->hidden_size; i++)
        rb_ary_store(hidden_layer, i, Node_to_hash(network->hidden_layer[i]));
    rb_hash_aset(result, SYM("hidden_layer"), hidden_layer);
    output_layer = rb_ary_new2(network->output_size);
    for (i = 0; i < network->output_size; i++)
        rb_ary_store(output_layer, i, Node_to_hash(network->output_layer[i]));
    rb_hash_aset(result, SYM("output_layer"), output_layer);
    rb_hash_aset(result, SYM("learned"), INT2NUM(network->learned));
    return result;
}

/*
 * Helper Functions
 */

static void transform_data(double *data_vector, VALUE data)
{
    int i;
    VALUE current;
    for (i = 0; i < RARRAY_LEN(data); i++) {
        current = rb_ary_entry(data, i);
        CAST2FLOAT(current);
        data_vector[i] = RFLOAT_VALUE(current);
    }
}

static void feed2layer(int in_size, int out_size, Node **layer, double *data)
{
    int i, j;
    double sum;
    for (i = 0; i < out_size; i++) {
        sum = 0.0;
        for (j = 0; j < in_size; j++)
            sum += layer[i]->weights[j] * data[j];
        layer[i]->output = 1.0 / (1.0 + exp(-sum));
        /* sigmoid(sum), beta = 0.5 */
    }
}

/*
 * Ruby API
 */

/*
 * call-seq: learn(data, desired, max_error, eta)
 *
 * The network should respond with the Array _desired_ (size == output_size),
 * if it was given the Array _data_ (size == input_size). The learning process
 * ends, if the resulting error sinks below _max_error_ and convergence is
 * assumed. A lower _eta_ parameter leads to slower learning, because of low
 * weight changes. A too high _eta_ can lead to wildly oscillating weights, and
 * result in slower learning or no learning at all. The last two parameters
 * should be chosen appropriately to the problem at hand. ;)
 *
 * The return value is an Integer value, that denotes the number of learning
 * steps, which were necessary, to learn the _data_, or _max_iterations_, if
 * the _data_ couldn't be learned.
 */
static VALUE rb_network_learn(VALUE self, VALUE data, VALUE desired, VALUE
        max_error, VALUE eta)
{
    Network *network;
    double max_error_float, eta_float, error, sum,
        *output_delta, *hidden_delta;
    long i, j, count;

    Data_Get_Struct(self, Network, network);

	Check_Type(data, T_ARRAY);
    if (RARRAY_LEN(data) != network->input_size)
        rb_raise(rb_cNeuroError, "size of data != input_size");
    transform_data(network->tmp_input, data);

	Check_Type(desired, T_ARRAY);
    if (RARRAY_LEN(desired) != network->output_size)
        rb_raise(rb_cNeuroError, "size of desired != output_size");
    transform_data(network->tmp_output, desired);
    CAST2FLOAT(max_error);
    max_error_float = RFLOAT_VALUE(max_error);
    if (max_error_float <= 0) rb_raise(rb_cNeuroError, "max_error <= 0");
    max_error_float *= 2.0;
    CAST2FLOAT(eta);
    eta_float = RFLOAT_VALUE(eta);
    if (eta_float <= 0) rb_raise(rb_cNeuroError, "eta <= 0");

    output_delta = ALLOCA_N(double, network->output_size);
    hidden_delta = ALLOCA_N(double, network->hidden_size);
    for(count = 0; count < network->max_iterations; count++) {
        feed;

        /* Compute output weight deltas and current error */
        error = 0.0;    
        for (i = 0; i < network->output_size; i++) {
            output_delta[i] = network->tmp_output[i] -
                network->output_layer[i]->output;
            error += output_delta[i] * output_delta[i];
            output_delta[i] *= network->output_layer[i]->output *
                (1.0 - network->output_layer[i]->output);
            /* diff * (sigmoid' = 2 * output  * beta * (1 - output)) */

        }

        if (count % network->debug_step == 0)
            Network_debug_error(network, count, error, max_error_float);

        /* Get out if error is below max_error ^ 2 */
        if (error < max_error_float) goto CONVERGED;

        /* Compute hidden weight deltas */
        
		for (i = 0; i < network->hidden_size; i++) {
            sum = 0.0;
			for (j = 0; j < network->output_size; j++)
				sum += output_delta[j] *
                    network->output_layer[j]->weights[i];
			hidden_delta[i] = sum * network->hidden_layer[i]->output *
                (1.0 - network->hidden_layer[i]->output);
            /* sum * (sigmoid' = 2 * output  * beta * (1 - output)) */
		}
        
        /* Adjust weights */

		for (i = 0; i < network->output_size; i++)
			for (j = 0; j < network->hidden_size; j++)
                network->output_layer[i]->weights[j] +=
                    eta_float * output_delta[i] *
                    network->hidden_layer[j]->output;

		for (i = 0; i < network->hidden_size; i++)
			for (j = 0; j < network->input_size; j++)
				network->hidden_layer[i]->weights[j] += eta_float *
                    hidden_delta[i] * network->tmp_input[j];
    }
    Network_debug_bail_out(network);
CONVERGED:
    network->learned++;
    return INT2NUM(count);
}

/*
 * call-seq: decide(data)
 *
 * The network is given the Array _data_ (size has to be == input_size), and it
 * responds with another Array (size == output_size) by returning it.
 */
static VALUE rb_network_decide(VALUE self, VALUE data)
{
    Network *network;
    VALUE result;
    long i;

    Data_Get_Struct(self, Network, network);

	Check_Type(data, T_ARRAY);
    if (RARRAY_LEN(data) != network->input_size)
        rb_raise(rb_cNeuroError, "size of data != input_size");
    transform_data(network->tmp_input, data);
    feed;
    result = rb_ary_new2(network->output_size);
    for (i = 0; i < network->output_size; i++) {
        rb_ary_store(result, i,
            rb_float_new(network->output_layer[i]->output));
    }
    return result;
}

/*
 * Returns the _input_size_ of this Network as an Integer. This is the number
 * of weights, that are connected to the input of the hidden layer.
 */
static VALUE rb_network_input_size(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->input_size);
}

/*
 * Returns the _hidden_size_ of this Network as an Integer. This is the number of nodes in
 * the hidden layer.
 */
static VALUE rb_network_hidden_size(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->hidden_size);
}

/*
 * Returns the _output_size_ of this Network as an Integer. This is the number
 * of nodes in the output layer.
 */
static VALUE rb_network_output_size(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->output_size);
}

/*
 * Returns the number of calls to #learn as an integer.
 */
static VALUE rb_network_learned(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->learned);
}

/*
 * Returns nil, if debugging is switchted off. Returns the IO object, that is
 * used for debugging output, if debugging is switchted on.
 */
static VALUE rb_network_debug(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return network->debug;
}

/*
 * call-seq: debug=(io)
 *
 * Switches debugging on, if _io_ is an IO object. If it is nil,
 * debugging is switched off.
 */
static VALUE rb_network_debug_set(VALUE self, VALUE io)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    network->debug = io;
    return io;
}

/*
 * Returns the Integer number of steps, that are done during learning, before a
 * debugging message is printed to #debug.
 */
static VALUE rb_network_debug_step(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->debug_step);
}

/*
 * call-seq: debug_step=(step)
 *
 * Sets the number of steps, that are done during learning, before a
 * debugging message is printed to _step_. If _step_ is equal to or less than 0
 * the default value (=1000) is set.
 */ 
static VALUE rb_network_debug_step_set(VALUE self, VALUE step)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    Check_Type(step, T_FIXNUM);
    network->debug_step = NUM2INT(step);
    if (network->debug_step <= 0) network->debug_step = DEFAULT_DEBUG_STEP;
    return step;
}

/*
 * Returns the maximal number of iterations, that are done before #learn gives
 * up and returns without having learned the given _data_.
 */
static VALUE rb_network_max_iterations(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return INT2NUM(network->max_iterations);
}

/*
 * call-seq: max_iterations=(iterations)
 *
 * Sets the maximal number of iterations, that are done before #learn gives
 * up and returns without having learned the given _data_, to _iterations_.
 * If _iterations_ is equal to or less than 0, the default value (=10_000) is
 * set.
 */ 
static VALUE rb_network_max_iterations_set(VALUE self, VALUE iterations)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    Check_Type(iterations, T_FIXNUM);
    network->max_iterations = NUM2INT(iterations);
    if (network->max_iterations <= 0)
        network->max_iterations = DEFAULT_MAX_ITERATIONS;
    return iterations;
}

/*
 * Returns the state of the network as a Hash.
 */
static VALUE rb_network_to_h(VALUE self)
{
    Network *network;

    Data_Get_Struct(self, Network, network);
    return Network_to_hash(network);
}


/*
 * Returns a short string for the network.
 */
static VALUE rb_network_to_s(VALUE self)
{
    Network *network;
    VALUE argv[5];
    int argc = 5;

    Data_Get_Struct(self, Network, network);
    argv[0] = rb_str_new2("#<%s:%u,%u,%u>");
    argv[1] = rb_funcall(self, id_class, 0, 0);
    argv[1] = rb_funcall(argv[1], id_name, 0, 0);
    argv[2] = INT2NUM(network->input_size);
    argv[3] = INT2NUM(network->hidden_size);
    argv[4] = INT2NUM(network->output_size);
    return rb_f_sprintf(argc, argv);
}

/* Allocation and Construction */

static void rb_network_mark(Network *network)
{
    if (!NIL_P(network->debug)) rb_gc_mark(network->debug);
}

static void rb_network_free(Network *network)
{
    long i;
    for (i = 0; i < network->hidden_size; i++)
        Node_destroy(network->hidden_layer[i]);
    MEMZERO(network->hidden_layer, Node*, network->hidden_size);
    xfree(network->hidden_layer);
    for (i = 0; i < network->output_size; i++)
        Node_destroy(network->output_layer[i]);
    MEMZERO(network->output_layer, Node*, network->output_size);
    xfree(network->output_layer);
    MEMZERO(network->tmp_input, double, network->input_size);
    xfree(network->tmp_input);
    MEMZERO(network->tmp_hidden, double, network->hidden_size);
    xfree(network->tmp_hidden);
    MEMZERO(network->tmp_output, double, network->output_size);
    xfree(network->tmp_output);
    MEMZERO(network, Network, 1);
    xfree(network);
}

static VALUE rb_network_s_allocate(VALUE klass)
{
    Network *network = Network_allocate();
    return Data_Wrap_Struct(klass, rb_network_mark, rb_network_free, network);
}

/*
 * call-seq: new(input_size, hidden_size, output_size)
 *
 * Returns a Neuro::Network instance of the given size specification.
 */
static VALUE rb_network_initialize(int argc, VALUE *argv, VALUE self)
{
    Network *network;
    VALUE input_size, hidden_size, output_size;

    rb_scan_args(argc, argv, "3", &input_size, &hidden_size, &output_size);
	Check_Type(input_size, T_FIXNUM);
	Check_Type(hidden_size, T_FIXNUM);
	Check_Type(output_size, T_FIXNUM);
    Data_Get_Struct(self, Network, network);
    Network_init(network, NUM2INT(input_size), NUM2INT(hidden_size),
        NUM2INT(output_size), 0);
    Network_init_weights(network);
    return self;
}

/*
 * Returns the serialized data for this Network instance for the Marshal
 * module.
 */
static VALUE rb_network_dump(int argc, VALUE *argv, VALUE self)
{
    VALUE port = Qnil, hash;
    Network *network;

    rb_scan_args(argc, argv, "01", &port);
    Data_Get_Struct(self, Network, network);
    hash = Network_to_hash(network);
    return rb_marshal_dump(hash, port);
}

static VALUE
setup_layer_i(VALUE node_hash, VALUE pair_value)
{
    VALUE *pair = (VALUE *) pair_value;
    Node **layer = (Node **) pair[0];
    int index = (int) pair[1];
    Check_Type(node_hash, T_HASH);
    layer[index] = Node_from_hash(node_hash);
    pair[1] = (VALUE) 1 + index;
    return Qnil;
}

/*
 * call-seq: Neuro::Network.load(string)
 *
 * Creates a Network object plus state
 * from the Marshal dumped string _string_, and returns it.
 */
static VALUE rb_network_load(VALUE klass, VALUE string)
{
    VALUE input_size, hidden_size, output_size, learned,
        hidden_layer, output_layer, pair[2];
    Network *network;
    VALUE hash = rb_marshal_load(string);
    input_size = rb_hash_aref(hash, SYM("input_size"));
    hidden_size = rb_hash_aref(hash, SYM("hidden_size"));
    output_size = rb_hash_aref(hash, SYM("output_size"));
    learned = rb_hash_aref(hash, SYM("learned"));
	Check_Type(input_size, T_FIXNUM);
	Check_Type(hidden_size, T_FIXNUM);
	Check_Type(output_size, T_FIXNUM);
	Check_Type(learned, T_FIXNUM);
    network = Network_allocate();
    Network_init(network, NUM2INT(input_size), NUM2INT(hidden_size),
            NUM2INT(output_size), NUM2INT(learned));
    hidden_layer = rb_hash_aref(hash, SYM("hidden_layer"));
    output_layer = rb_hash_aref(hash, SYM("output_layer"));
    Check_Type(hidden_layer, T_ARRAY);
    Check_Type(output_layer, T_ARRAY);
    pair[0] = (VALUE) network->hidden_layer;
    pair[1] = (VALUE) 0;
    rb_iterate(rb_each, hidden_layer, setup_layer_i, (VALUE) pair);
    pair[0] = (VALUE) network->output_layer;
    pair[1] = (VALUE) 0;
    rb_iterate(rb_each, output_layer, setup_layer_i, (VALUE) pair);
    return Data_Wrap_Struct(klass, NULL, rb_network_free, network);
}

void Init_neuro()
{
    rb_require("neuro/version");
    rb_mNeuro = rb_define_module("Neuro");
    rb_cNetwork = rb_define_class_under(rb_mNeuro, "Network", rb_cObject);
    rb_cNeuroError = rb_define_class("NetworkError", rb_eStandardError);
    rb_define_alloc_func(rb_cNetwork, rb_network_s_allocate);
    rb_define_method(rb_cNetwork, "initialize", rb_network_initialize, -1);
    rb_define_method(rb_cNetwork, "learn", rb_network_learn, 4);
    rb_define_method(rb_cNetwork, "decide", rb_network_decide, 1);
    rb_define_method(rb_cNetwork, "input_size", rb_network_input_size, 0);
    rb_define_method(rb_cNetwork, "hidden_size", rb_network_hidden_size, 0);
    rb_define_method(rb_cNetwork, "output_size", rb_network_output_size, 0);
    rb_define_method(rb_cNetwork, "learned", rb_network_learned, 0);
    rb_define_method(rb_cNetwork, "debug", rb_network_debug, 0);
    rb_define_method(rb_cNetwork, "debug=", rb_network_debug_set, 1);
    rb_define_method(rb_cNetwork, "debug_step", rb_network_debug_step, 0);
    rb_define_method(rb_cNetwork, "debug_step=", rb_network_debug_step_set, 1);
    rb_define_method(rb_cNetwork, "max_iterations", rb_network_max_iterations, 0);
    rb_define_method(rb_cNetwork, "max_iterations=", rb_network_max_iterations_set, 1);
    rb_define_method(rb_cNetwork, "_dump", rb_network_dump, -1);
    rb_define_method(rb_cNetwork, "dump", rb_network_dump, -1);
    rb_define_method(rb_cNetwork, "to_h", rb_network_to_h, 0);
    rb_define_method(rb_cNetwork, "to_s", rb_network_to_s, 0);
    rb_define_singleton_method(rb_cNetwork, "_load", rb_network_load, 1);
    rb_define_singleton_method(rb_cNetwork, "load", rb_network_load, 1);
    id_to_f = rb_intern("to_f");
    id_class = rb_intern("class");
    id_name = rb_intern("name");
}

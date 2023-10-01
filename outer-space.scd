s.boot;
s.reboot;

s.plotTree;
s.meter;

f = FreqScope(server: s);

~scale = Scale.minor;
~synths = Array.newClear(128);

(
    ~isInScale = { | note, scale |
        ~scale.degrees.includesEqual(note % 12).postln;
    };
)

(
MIDIClient.init();
MIDIIn.connectAll();
)

MIDIFunc.trace(true);
MIDIFunc.trace(false);

(
    ~noteOnMidiFunc.free();
    ~noteOffMidiFunc.free();
    ~ccMidiFunc.free();
    ~touchMidiFunc.free();
    ~bendOnMidiFunc.free();

    ~noteOnMidiFunc = MIDIFunc.noteOn({
        arg velo, note;

        if ( ~isInScale.value(note, ~scale),
            {
                ~synths[note] = Synth(
                    \keys,
                    [
                        \out, 18,
                        \freq, note.midicps,
                        \amSinOscFreq, ~keysAmSinOscFreq,
                        \amPulseFreq, ~keysAmPulseFreq,
                        \bendFreq, ~keysBendFreq,
                    ],
                    ~keysGroup);
            }
        );
    });

    ~noteOffMidiFunc = MIDIFunc.noteOff({
        arg velo, note;

        ~synths[note].set(\gate, 0);
    });

    ~ccMidiFunc = MIDIFunc.cc({
        arg val, num;

        switch (num,
            70, {
                ~keysAmSinOscFreq = linexp(val, 0, 127, 0.3, 9.0);
                ~keysGroup.set(\amSinOscFreq, ~keysAmSinOscFreq); },
            71, {
                ~keysAmPulseFreq = linexp(val, 0, 127, 0.1, 10.0);
                ~keysGroup.set(\amPulseFreq, ~keysAmPulseFreq); });
    });

    ~touchMidiFunc = MIDIFunc.touch({
        arg ...args;

        postln("touch: " + args);
    });

    ~bendOnMidiFunc = MIDIFunc.bend({
        arg num;
        ~keysBendFreq = linlin(num, 0, 16383, -50.0, 50.0);
        ~keysGroup.set(\bendFreq, ~keysBendFreq);
    });
)

(
    ~noteOnMidiFunc.free();
    ~noteOffMidiFunc.free();
    ~ccMidiFunc.free();
    ~touchMidiFunc.free();
    ~bendOnMidiFunc.free();
)

(
    ~synthsGroup = Group.head(s);
    ~keysGroup = Group(~synthsGroup);
    ~fxGroup = Group.tail(s);
)

~keysAmSinOscFreq = 1;
~keysAmPulseFreq = 1;
~keysBendFreq = 0;

(
    SynthDef(\fx, { | in = 16, out = 0 |
        var signal = In.ar(in, 2);

        signal = Limiter.ar(signal, -5.dbamp, 0.3);

        Out.ar(out, signal);
    }).add;
)

(
    SynthDef(\keys_fx, { | in = 18, out = 16 |
        var signal = In.ar(in, 2);

        signal = Limiter.ar(signal, dur: 0.3);

        Out.ar(out, signal);
    }).add;
)

(
    ~fx.free;
    ~fx = Synth(\fx, [], ~fxGroup);

    ~keys_fx.free;
    ~keys_fx = Synth(\keys_fx, [], ~fx, \addBefore);
)

(
    SynthDef(\ambient, { | out = 0, freq = 300, amp = 0.1, env_attack = 0.01 |
        var signal = SinOsc.ar(freq + LFNoise1.ar(rrand(1, 30), rrand(1, 10)));
        var am = LFNoise1.ar(rrand(1, 10));
        var env = Env([0, 1, 1, 0], [rand(env_attack, env_attack + 1), rand(5, 15), rrand(3, 10)]);
        var envGen = EnvGen.ar(env, doneAction: Done.freeSelf);

        signal = signal * am;
        signal = signal * envGen;
        signal = signal * amp;

        Out.ar(out, Pan2.ar(signal, rrand(-1.0, 1.0)));
    }).add;

    SynthDef(\phrase, { | out = 0, freq = 300, amp = 0.1 |
        var sinOscAmFreq = rrand(1, 10);
        var pulseAmFreq = rrand(1, 10);
        var signal =
            SinOsc.ar(freq, 0, LFNoise0.ar(sinOscAmFreq)) +
            Pulse.ar(freq, rrand(0.1, 0.9), LFNoise0.ar(pulseAmFreq));
        var env = Env([0, 1, 1, 0], [rrand(0.01, 0.3), rrand(1, 3), rrand(3, 10)]);
        var envGen = EnvGen.ar(env, doneAction: Done.freeSelf);

        signal = LPF.ar(signal, LFNoise0.ar(3, 500, 1000));

        signal = signal * envGen;
        signal = signal * amp;


        Out.ar(out, Pan2.ar(signal));
    }).add;

    SynthDef(\ascending_phrase, { | out = 0, freq = 300, amp = 0.1 |
        var signal = Pulse.ar(freq, LFNoise0.ar(1, 0.9));
        var env = Env([0, 1, 1, 0], [rrand(0.01, 0.3), rrand(1, 3), rrand(3, 10)]);
        var envGen = EnvGen.ar(env, doneAction: Done.freeSelf);

        signal = signal * LFSaw.ar(rrand(1.0, 3.0));

        signal = LPF.ar(signal, 1000);

        signal = signal * envGen;
        signal = signal * amp;


        Out.ar(out, Pan2.ar(signal));
    }).add;

    SynthDef(\beep, { | out = 0, freq = 1000, amp = 0.1 |
        var signal = Pulse.ar(freq, mul: amp);
        var env = Env([0, 1, 1, 0], [0.01, 0.1, 0.05]);
        var envGen = EnvGen.ar(env, doneAction: Done.freeSelf);

        signal = signal * envGen;

        Out.ar(out, Pan2.ar(signal, rrand(-1.0, 1.0)));
    }).add;

    SynthDef(\keys, {
        arg
            out = 0,
            gate = 1,
            freq = 300,
            amp = 0.3,
            amSinOscFreq = ~keysAmSinOscFreq,
            amPulseFreq = ~keysAmPulseFreq,
            bendFreq = ~keysBendFreq;

        var signal = SinOsc.ar(freq + bendFreq) + LFTri.ar(freq + bendFreq);
        var am = SinOsc.ar(amSinOscFreq) + Pulse.ar(amPulseFreq);
        var env = Env([0, 1, 0], [0.3, 10], -5, 1);
        var envGen = EnvGen.ar(env, gate, doneAction: Done.freeSelf);

        signal = signal * am * envGen * amp;

        Out.ar(out, Pan2.ar(signal, LFNoise0.ar(3)));
    }).add;
)

(
    Tdef(\task_ambient_low, {
        {
            var freq = ~scale.degreeToFreq(
                rrand(0, 6), 60.midicps, rrand(-2, -1));

            Synth(\ambient, [\out, 16, \freq, freq, \amp, 0.5, \env_attack, 3], ~synthsGroup);

            rrand(1, 5).wait;
        }.loop;
    });

    Tdef(\task_ambient_mid, {
        {
            var freq = ~scale.degreeToFreq(
                rrand(0, 6), 60.midicps, rrand(0, 1));

            Synth(\ambient, [\out, 16, \freq, freq], ~synthsGroup);

            rrand(0.01, 1).wait;
        }.loop;
    });

    Tdef(\task_phrase, {
        var degree = [[0, 2, 4], [2, 4, 6], [6, 8, 10], [4, 6, 8], [7, 9, 11]];

        {
            var octave = rrand(-1, 1);

            degree.do({
                arg i;

                var freq = ~scale.degreeToFreq(i, 60.midicps, octave);

                Synth(\phrase, [\out, 16, \freq, freq, \amp, rrand(0.1, 0.5)], ~synthsGroup);

                rrand(1, 3).wait;
            });

            rrand(1, 30).wait;
        }.loop;
    });

    Tdef(\task_ascending_phrase, {
        var degree = [
            [0, 0 + 2, 0 + 4],
            [1, 1 + 2, 1 + 4],
            [2, 2 + 2, 2 + 4],
            [3, 3 + 2, 3 + 4],
            [4, 4 + 2, 4 + 4],

            [2, 2 + 2, 2 + 4],
            [3, 3 + 2, 3 + 4],
            [4, 4 + 2, 4 + 4],
            [5, 5 + 2, 5 + 4],
            [6, 6 + 2, 6 + 4],

            [4, 4 + 2, 4 + 4],
            [5, 5 + 2, 5 + 4],
            [6, 6 + 2, 6 + 4],
        ];

        {
            var octave = rrand(-1, 1);

            degree.do({
                arg i;

                var freq = ~scale.degreeToFreq(i, 60.midicps, octave);

                Synth(\ascending_phrase, [\out, 16, \freq, freq, \amp, rrand(0.05, 0.3)], ~synthsGroup);

                rrand(0.1, 1.0).wait;
            });

            rrand(3, 7).wait;
        }.loop;
    });

    Tdef(\task_beep, {
        {
            var freq = [
                ~scale.degreeToFreq(0, 60.midicps, 3),
                ~scale.degreeToFreq(0, 60.midicps, 4),
                ~scale.degreeToFreq(0, 60.midicps, 5)];

            Synth(\beep, [\out, 16, \freq, freq, \amp, 0.3], ~synthsGroup);

            rrand(5.0, 10.0).wait;
        }.loop;
    });
)

Tdef(\task_ambient_low).play;
Tdef(\task_ambient_low).stop;

Tdef(\task_ambient_mid).play;
Tdef(\task_ambient_mid).stop;

Tdef(\task_phrase).play;
Tdef(\task_phrase).stop;

Tdef(\task_ascending_phrase).play;
Tdef(\task_ascending_phrase).stop;

Tdef(\task_beep).play;
Tdef(\task_beep).stop;

// Recording
(
    ~recorder = Recorder(s);

    ~recorder.recHeaderFormat = "flac";
    ~recorder.recSampleFormat = "int24";
    ~recorder.filePrefix = "outer_space_";
)

~recorder.record();
~recorder.stopRecording();
